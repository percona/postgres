/*
 * Record-level WAL encryption hook.
 *
 * An extension loaded through shared_preload_libraries registers a
 * PerconaXLogRecordCrypt with SetPerconaXLogRecordCrypt(). XLogInsert then
 * encrypts the body of every record the hook wants encrypted, and
 * XLogReadRecord hands the body back for decryption. See XLR_ENCRYPTED in
 * xlogrecord.h for the record layout; the encrypted body is
 *
 *		prefix		written by encrypt_begin, for example a key id and an IV
 *		ciphertext	as long as the plaintext body
 *		suffix		written by encrypt_end, for example an authentication tag
 *
 * The body is encrypted as a stream, in the pieces XLogInsert has it in, so
 * no buffer for a whole record is needed and nothing is allocated, however
 * large the record is. That happens while the record is copied to the WAL
 * buffers, with a WAL insertion lock held.
 */
#ifndef PERCONA_XLOG_CRYPT_H
#define PERCONA_XLOG_CRYPT_H

#include "access/rmgr.h"
#include "access/xlogrecord.h"

/* upper bounds for max_prefix_len and max_suffix_len */
#define PerconaXLogRecordCryptMaxPrefix 64
#define PerconaXLogRecordCryptMaxSuffix 64

typedef struct PerconaXLogRecordCrypt
{
	/*
	 * Most bytes encrypt_begin and encrypt_end may ask for. XLogInsert
	 * checks a record against XLogRecordMaxSize with them, before the
	 * actual lengths are known.
	 */
	uint32		max_prefix_len;
	uint32		max_suffix_len;

	/*
	 * Called in every process that has shared memory, once it is set up:
	 * the postmaster after creating it (again after a crash restart), each
	 * forked child right after the fork, EXEC_BACKEND children after
	 * attaching, single-user mode. Processes without shared memory (the
	 * logger) and frontend programs never call it. May be NULL.
	 *
	 * The hook may already hold state from an earlier call in the same
	 * address space, inherited through fork or left by the previous
	 * postmaster incarnation: the callback must re-initialize anything
	 * per-process (cipher contexts, counters, pids) every time, and must
	 * not assume a fresh process. CurrentMemoryContext is TopMemoryContext.
	 * Available: GUCs, shared memory pointers set up by the shmem startup
	 * hook, spinlocks and atomics, MyProcPid. Not available: MyProc,
	 * LWLocks, MyBackendType, catalogs, transactions. Do not raise ERROR or
	 * worse in the postmaster unless the server must not start.
	 *
	 * Whatever the encrypt callbacks need has to be allocated here.
	 */
	void		(*process_init) (void);

	/*
	 * Should the record XLogInsert is about to assemble be encrypted?
	 *
	 * Most callers wrap XLogInsert in a critical section, so this has to be
	 * treated as one: no allocation, no error below PANIC.
	 *
	 * Besides the rmgr and the caller's info byte, the block references of
	 * the record, and with them the relations it changes, are available
	 * through XLogInsertGetBlockTag(). That is true for the encrypt
	 * callbacks as well.
	 */
	bool		(*wants_encryption) (RmgrId rmid, uint8 info);

	/*
	 * Start encrypting a record body: choose key and IV, write the prefix
	 * and say how long prefix and suffix are, each at most the declared
	 * maximum. The lengths may differ from record to record.
	 *
	 * hdr is the header as assembled: xl_tot_len is SizeOfXLogRecord plus
	 * the plaintext length, XLR_ENCRYPTED is clear, xl_prev and xl_crc are
	 * zero. decrypt sees the header as it is on disk, see
	 * PerconaXLogRecordCryptTotalLen() for its xl_tot_len; xl_prev is not
	 * known yet, so a hook that binds the header must leave it out.
	 *
	 * Called before the WAL insertion lock is taken, but usually inside the
	 * caller's critical section: no allocation, no error below PANIC. The
	 * record may be dropped after this call and assembled again, when a
	 * checkpoint changed what it has to contain, so a begin is not always
	 * followed by updates and an end.
	 */
	void		(*encrypt_begin) (const XLogRecord *hdr, char *prefix,
								  uint32 *prefix_len, uint32 *suffix_len);

	/*
	 * Encrypt the next len bytes of the body from in to out. The cipher
	 * must be a stream: len bytes out for len bytes in, cut anywhere. out
	 * never overlaps in.
	 *
	 * Called with a WAL insertion lock held, and out is the WAL buffer: no
	 * allocation, no locks, no error below PANIC, and nothing slow.
	 */
	void		(*encrypt_update) (const char *in, char *out, size_t len);

	/*
	 * Finish the record and write the suffix, of the length encrypt_begin
	 * announced. Same rules as encrypt_update. May be NULL if
	 * max_suffix_len is zero.
	 */
	void		(*encrypt_end) (char *suffix);

	/*
	 * Decrypt body (len bytes: prefix, ciphertext and suffix) into out and
	 * set *plain_len. Returns false if the body cannot be decrypted. hdr is
	 * the on-disk header, XLR_ENCRYPTED still set. len may be anything a
	 * CRC-valid record carries, so the hook must reject a body shorter than
	 * its own prefix and suffix instead of reading past it.
	 *
	 * out either equals body exactly (a record assembled from several pages
	 * is decrypted in place) or does not overlap it at all (a single-page
	 * record is decrypted out of the page cache), never partially. In the
	 * in-place case a hook with a prefix has to deal with the ciphertext
	 * not starting where the plaintext goes (copy its prefix out, then
	 * memmove or decrypt through scratch).
	 *
	 * Runs outside critical sections and may allocate. It may fetch a key
	 * it does not have, but only while INTERRUPTS_CAN_BE_PROCESSED(): the
	 * reader is also used with an LWLock held, where no I/O may happen.
	 * That is the case when prepared transactions are read back from WAL
	 * under TwoPhaseStateLock (checkpoints, recovery of prepared
	 * transactions, LookupGXact()). Those records were inserted or replayed
	 * by this server before, so a hook that keeps the keys it used where
	 * every process finds them has nothing to fetch there. Recovery and its
	 * read-ahead hold no LWLock.
	 *
	 * decrypt may run ahead of replay (recovery_prefetch). A failure there
	 * is not final: the record is tried again when replay has reached it,
	 * and only then it is an error. So decrypt can be called more than once
	 * for a record, and a record that cannot be decrypted has to be
	 * reported by returning false, not by raising an error.
	 */
	bool		(*decrypt) (const XLogRecord *hdr, const char *body,
							size_t len, char *out, size_t *plain_len);

	/*
	 * Describe the last record this process decrypted, for pg_waldump and
	 * similar tools: a short string such as a key identifier, written to
	 * buf (bufsz bytes, NUL-terminated). Returns the length written, 0 for
	 * nothing to say. May be NULL. Only meaningful right after a successful
	 * decrypt in the same process. Readers that decode ahead of consumption
	 * (the recovery prefetcher) cannot rely on "last"; pg_waldump decodes
	 * one record at a time.
	 */
	size_t		(*describe_last) (char *buf, size_t bufsz);
} PerconaXLogRecordCrypt;

/*
 * xl_tot_len of the record on disk, from the xl_tot_len encrypt_begin sees
 * and the lengths it returns.
 */
#define PerconaXLogRecordCryptTotalLen(plain_tot_len, prefix_len, suffix_len) \
	((plain_tot_len) + (prefix_len) + (suffix_len) + SizeOfXLogRecordTrailer)

/* NULL unless an extension registered one; no PGDLLIMPORT, like xlog_smgr */
extern const PerconaXLogRecordCrypt *percona_xlog_record_crypt;
extern void SetPerconaXLogRecordCrypt(const PerconaXLogRecordCrypt *xlcrypt);

#ifndef FRONTEND
#include "utils/memutils.h"

static inline void
PerconaXLogRecordCryptProcessInit(void)
{
	MemoryContext oldcxt;

	if (percona_xlog_record_crypt == NULL ||
		percona_xlog_record_crypt->process_init == NULL)
		return;
	oldcxt = MemoryContextSwitchTo(TopMemoryContext);
	percona_xlog_record_crypt->process_init();
	MemoryContextSwitchTo(oldcxt);
}
#endif

#endif							/* PERCONA_XLOG_CRYPT_H */
