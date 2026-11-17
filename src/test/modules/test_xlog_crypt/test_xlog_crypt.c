/*-------------------------------------------------------------------------
 *
 * test_xlog_crypt.c
 *		Toy PerconaXLogRecordCrypt hook for the core tests.
 *
 * Not a cipher: XOR with a key from a GUC, a prefix of configurable size
 * holding a counter, an optional suffix holding a sum of the plaintext, and
 * the header folded in. Enough to tell plaintext from "ciphertext" on disk
 * and to drive every piece of core plumbing: prefix and suffix of any
 * length, a body encrypted in pieces, decrypt failure, a key that arrives
 * by redo, opt-out per rmgr and per relation, frontend opaque records.
 * Every contract violation by core is a PANIC or ERROR here, not an Assert,
 * so the TAP tests catch it in any build; that includes a process using the
 * hook without its own process_init call, checked by pid.
 *
 * Portions Copyright (c) 1996-2026, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 * IDENTIFICATION
 *		src/test/modules/test_xlog_crypt/test_xlog_crypt.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include <limits.h>

#include "access/percona_xlog_crypt.h"
#include "access/xlog.h"
#include "access/xloginsert.h"
#include "access/xlogrecord.h"
#include "access/xlogrecovery.h"
#include "fmgr.h"
#include "miscadmin.h"
#include "utils/guc.h"

PG_MODULE_MAGIC;

#define TEST_KEY_LEN	8
#define TEST_MAX_PREFIX 64
#define TEST_MAX_SUFFIX 64

/* first prefix byte: its length, and whether the body ends with a suffix */
#define TEST_PREFIX_LEN_MASK	0x7F
#define TEST_HAS_SUFFIX			0x80

static int	test_overhead = 5;
static int	test_suffix = 0;
static bool test_enabled = true;
static bool test_fail_decrypt = false;
static int	test_fail_decrypt_rmgr = -1;
static int	test_late_key_rmgr = -1;
static bool test_xlog_rmgr_plaintext = false;
static int	test_plaintext_relfilenode = 0;
static char *test_key_text = NULL;	/* 16 hex digits */

/*
 * The key comes from a GUC so that every node of a test (primary, standby,
 * rewound copy) XORs with the same bytes, like a shared KMS would give.
 */
static uint8 test_key[TEST_KEY_LEN];
static pid_t test_init_pid = 0;

/* per process; collisions between backends are harmless for a toy */
static uint32 test_counter = 0;

/* test_block_refs() of the record wants_encryption was last asked about */
static uint32 wants_block_refs;

/* the record being encrypted, between encrypt_begin and encrypt_end */
static bool enc_active = false;
static uint32 enc_counter;
static uint8 enc_mix;
static size_t enc_len;			/* plaintext length announced by the header */
static size_t enc_done;
static uint32 enc_sum;
static uint32 enc_suffix_len;

/* what the last successful decrypt saw, for describe_last */
static uint32 test_last_overhead = 0;
static uint32 test_last_counter = 0;

static void
test_process_init(void)
{
	if (test_key_text == NULL ||
		strlen(test_key_text) != 2 * TEST_KEY_LEN ||
		strspn(test_key_text, "0123456789abcdefABCDEF") != 2 * TEST_KEY_LEN)
		elog(FATAL, "test_xlog_crypt.key must be %d hex digits",
			 2 * TEST_KEY_LEN);
	for (int i = 0; i < TEST_KEY_LEN; i++)
	{
		unsigned int v;

		if (sscanf(test_key_text + 2 * i, "%2x", &v) != 1)
			elog(FATAL, "test_xlog_crypt.key must be hex");
		test_key[i] = (uint8) v;
	}
	test_init_pid = MyProcPid;
}

/*
 * Digest of the block references of the record being inserted. Also tells
 * whether one of them is in the relation that is to stay plaintext.
 */
static uint32
test_block_refs(bool *plaintext_rel)
{
	uint32		digest = 0;

	for (int id = 0; id <= XLogInsertMaxBlockId(); id++)
	{
		RelFileLocator rlocator;
		ForkNumber	forknum;
		BlockNumber blkno;

		if (!XLogInsertGetBlockTag(id, &rlocator, &forknum, &blkno))
			continue;
		digest = digest * 31 + id + 1;
		digest = digest * 31 + rlocator.relNumber;
		digest = digest * 31 + (uint32) forknum;
		digest = digest * 31 + blkno;
		if (plaintext_rel != NULL && test_plaintext_relfilenode != 0 &&
			rlocator.relNumber == (RelFileNumber) test_plaintext_relfilenode)
			*plaintext_rel = true;
	}
	return digest;
}

static bool
test_wants_encryption(RmgrId rmid, uint8 info)
{
	bool		plaintext_rel = false;

	if (test_enabled && test_init_pid != MyProcPid)
		elog(PANIC, "test_xlog_crypt: process_init was not called in this process (pid %d)",
			 (int) MyProcPid);
	if (!test_enabled)
		return false;
	if (test_xlog_rmgr_plaintext && rmid == RM_XLOG_ID)
		return false;
	wants_block_refs = test_block_refs(&plaintext_rel);
	return !plaintext_rel;
}

/*
 * Fold the header into the mix: rmid, info without XLR_ENCRYPTED, xid, and
 * the length of the record on disk, which encrypt has to work out itself.
 */
static uint8
test_mix(const XLogRecord *hdr, uint32 disk_tot_len)
{
	return (uint8) hdr->xl_rmid ^ (uint8) (hdr->xl_info & ~XLR_ENCRYPTED) ^
		(uint8) hdr->xl_xid ^ (uint8) (hdr->xl_xid >> 8) ^
		(uint8) disk_tot_len ^ (uint8) (disk_tot_len >> 8);
}

/* pos is the offset of in[0] in the body */
static uint32
test_transform(const char *in, char *out, size_t len, size_t pos,
			   uint32 counter, uint8 mix, bool sum_in)
{
	uint32		sum = 0;

	for (size_t i = 0; i < len; i++)
	{
		char		c = in[i] ^ test_key[(pos + i + counter) % TEST_KEY_LEN] ^ mix;

		sum += (uint8) (sum_in ? in[i] : c);
		out[i] = c;
	}
	return sum;
}

static void
test_encrypt_begin(const XLogRecord *hdr, char *prefix,
				   uint32 *prefix_len, uint32 *suffix_len)
{
	if ((hdr->xl_info & XLR_ENCRYPTED) ||
		hdr->xl_tot_len <= SizeOfXLogRecord ||
		hdr->xl_prev != InvalidXLogRecPtr || hdr->xl_crc != 0)
		elog(PANIC, "test_xlog_crypt: encrypt_begin called with a header that breaks the contract");
	if (test_block_refs(NULL) != wants_block_refs)
		elog(PANIC, "test_xlog_crypt: encrypt_begin sees other block references than wants_encryption");

	/* a begin without an end is fine, the record was assembled again */
	enc_active = true;
	enc_counter = ++test_counter;
	enc_len = hdr->xl_tot_len - SizeOfXLogRecord;
	enc_done = 0;
	enc_sum = 0;
	enc_suffix_len = test_suffix;

	memset(prefix, 0, test_overhead);
	prefix[0] = (char) (test_overhead | (test_suffix > 0 ? TEST_HAS_SUFFIX : 0));
	if (test_overhead >= 1 + sizeof(uint32))
		memcpy(prefix + 1, &enc_counter, sizeof(uint32));
	else
		enc_counter = 0;

	enc_mix = test_mix(hdr, PerconaXLogRecordCryptTotalLen(hdr->xl_tot_len,
														   test_overhead,
														   test_suffix));
	*prefix_len = test_overhead;
	*suffix_len = test_suffix;
}

static void
test_encrypt_update(const char *in, char *out, size_t len)
{
	if (!enc_active)
		elog(PANIC, "test_xlog_crypt: encrypt_update called without encrypt_begin");
	if (len == 0 || enc_done + len > enc_len)
		elog(PANIC, "test_xlog_crypt: encrypt_update called with %zu bytes after %zu of %zu",
			 len, enc_done, enc_len);
	if (out < in + len && in < out + len)
		elog(PANIC, "test_xlog_crypt: encrypt_update called with overlapping buffers");

	enc_sum += test_transform(in, out, len, enc_done, enc_counter, enc_mix,
							  true);
	enc_done += len;
}

static void
test_encrypt_end(char *suffix)
{
	if (!enc_active)
		elog(PANIC, "test_xlog_crypt: encrypt_end called without encrypt_begin");
	if (enc_done != enc_len)
		elog(PANIC, "test_xlog_crypt: encrypt_end called after %zu of %zu bytes",
			 enc_done, enc_len);
	if (test_block_refs(NULL) != wants_block_refs)
		elog(PANIC, "test_xlog_crypt: encrypt_end sees other block references than wants_encryption");
	enc_active = false;

	if (enc_suffix_len == 0)
		return;
	memset(suffix, 0, enc_suffix_len);
	if (enc_suffix_len >= 1 + sizeof(uint32))
		memcpy(suffix, &enc_sum, sizeof(uint32));
	/* the last byte of the body tells decrypt where the ciphertext ends */
	suffix[enc_suffix_len - 1] = (char) enc_suffix_len;
}

static bool
test_decrypt(const XLogRecord *hdr, const char *body, size_t len, char *out,
			 size_t *plain_len)
{
	size_t		overhead;
	size_t		suffix_len = 0;
	size_t		clen;
	uint32		counter = 0;
	uint32		sum;
	uint32		expected_sum = 0;
	bool		check_sum = false;

	if (test_init_pid != MyProcPid)
		elog(ERROR, "test_xlog_crypt: process_init was not called in this process (pid %d)",
			 (int) MyProcPid);
	if (!(hdr->xl_info & XLR_ENCRYPTED) ||
		hdr->xl_tot_len != SizeOfXLogRecord + len + SizeOfXLogRecordTrailer ||
		hdr->xl_crc != 0)
		elog(ERROR, "test_xlog_crypt: decrypt called with a header that breaks the contract");
	if (out != body && out < body + len && body < out + len)
		elog(ERROR, "test_xlog_crypt: decrypt called with partially overlapping buffers");
	if (len < 1)
		return false;
	overhead = (uint8) body[0] & TEST_PREFIX_LEN_MASK;
	if ((uint8) body[0] & TEST_HAS_SUFFIX)
	{
		suffix_len = (uint8) body[len - 1];
		if (suffix_len < 1 || suffix_len > TEST_MAX_SUFFIX)
			return false;
	}
	if (overhead < 1 || overhead + suffix_len >= len)
		return false;
	clen = len - overhead - suffix_len;
	if (overhead >= 1 + sizeof(uint32))
		memcpy(&counter, body + 1, sizeof(uint32));
	/* read the suffix before an in-place decrypt can move over it */
	if (suffix_len >= 1 + sizeof(uint32))
	{
		memcpy(&expected_sum, body + overhead + clen, sizeof(uint32));
		check_sum = true;
	}

	sum = test_transform(body + overhead, out, clen, 0, counter,
						 test_mix(hdr, hdr->xl_tot_len), false);
	*plain_len = clen;
	if (out == body)
		memset(out + clen, 0xA5, overhead + suffix_len);
	if (check_sum && sum != expected_sum)
		return false;
	if (test_fail_decrypt)
		return false;
	if (test_fail_decrypt_rmgr == hdr->xl_rmid)
		return false;
	/* as if redo of the record before this one brought the key */
	if (test_late_key_rmgr == hdr->xl_rmid && RecoveryInProgress())
	{
		if (GetXLogReplayRecPtr(NULL) <= hdr->xl_prev)
		{
			elog(LOG, "test_xlog_crypt: no key yet for record of length %u",
				 hdr->xl_tot_len);
			return false;
		}
		elog(LOG, "test_xlog_crypt: key found for record of length %u",
			 hdr->xl_tot_len);
	}
	test_last_overhead = (uint32) overhead;
	test_last_counter = counter;
	return true;
}

/*
 * Nothing registers the toy in a frontend program, so pg_waldump never
 * calls this; compile-only coverage of the callback.
 */
static size_t
test_describe_last(char *buf, size_t bufsz)
{
	int			n;

	if (bufsz == 0)
		return 0;
	n = snprintf(buf, bufsz, "overhead=%u counter=%u",
				 test_last_overhead, test_last_counter);
	if (n < 0)
		return 0;
	return Min((size_t) n, bufsz - 1);
}

static PerconaXLogRecordCrypt test_crypt = {
	.max_prefix_len = TEST_MAX_PREFIX,
	.max_suffix_len = TEST_MAX_SUFFIX,
	.process_init = test_process_init,
	.wants_encryption = test_wants_encryption,
	.encrypt_begin = test_encrypt_begin,
	.encrypt_update = test_encrypt_update,
	.encrypt_end = test_encrypt_end,
	.decrypt = test_decrypt,
	.describe_last = test_describe_last,
};

void
_PG_init(void)
{
	if (!process_shared_preload_libraries_in_progress)
		ereport(ERROR,
				(errmsg("test_xlog_crypt must be loaded via \"shared_preload_libraries\"")));

	DefineCustomIntVariable("test_xlog_crypt.overhead",
							"Bytes the toy hook prepends to every record body.",
							NULL,
							&test_overhead,
							5, 1, TEST_MAX_PREFIX,
							PGC_POSTMASTER, 0,
							NULL, NULL, NULL);
	DefineCustomIntVariable("test_xlog_crypt.suffix",
							"Bytes the toy hook appends to every record body.",
							NULL,
							&test_suffix,
							0, 0, TEST_MAX_SUFFIX,
							PGC_POSTMASTER, 0,
							NULL, NULL, NULL);
	DefineCustomBoolVariable("test_xlog_crypt.enabled",
							 "Whether the toy hook encrypts records at all.",
							 NULL,
							 &test_enabled,
							 true,
							 PGC_POSTMASTER, 0,
							 NULL, NULL, NULL);
	DefineCustomBoolVariable("test_xlog_crypt.fail_decrypt",
							 "Make every decrypt report a failure.",
							 NULL,
							 &test_fail_decrypt,
							 false,
							 PGC_SIGHUP, 0,
							 NULL, NULL, NULL);
	DefineCustomIntVariable("test_xlog_crypt.fail_decrypt_rmgr",
							"Make decrypt report a failure for records of this rmgr.",
							NULL,
							&test_fail_decrypt_rmgr,
							-1, -1, RM_MAX_ID,
							PGC_SIGHUP, 0,
							NULL, NULL, NULL);
	DefineCustomIntVariable("test_xlog_crypt.late_key_rmgr",
							"Make decrypt report a failure for records of this rmgr until replay has reached them.",
							NULL,
							&test_late_key_rmgr,
							-1, -1, RM_MAX_ID,
							PGC_SIGHUP, 0,
							NULL, NULL, NULL);
	DefineCustomBoolVariable("test_xlog_crypt.xlog_rmgr_plaintext",
							 "Leave RM_XLOG_ID records plaintext.",
							 NULL,
							 &test_xlog_rmgr_plaintext,
							 false,
							 PGC_SIGHUP, 0,
							 NULL, NULL, NULL);
	DefineCustomIntVariable("test_xlog_crypt.plaintext_relfilenode",
							"Leave records with a block of this relation plaintext.",
							NULL,
							&test_plaintext_relfilenode,
							0, 0, INT_MAX,
							PGC_SIGHUP, 0,
							NULL, NULL, NULL);
	DefineCustomStringVariable("test_xlog_crypt.key",
							   "Hex key shared by every node of a test.",
							   NULL,
							   &test_key_text,
							   "0123456789abcdef",
							   PGC_POSTMASTER, 0,
							   NULL, NULL, NULL);
	MarkGUCPrefixReserved("test_xlog_crypt");

	/* tight bounds, so that core is caught asking for or allowing more */
	test_crypt.max_prefix_len = test_overhead;
	test_crypt.max_suffix_len = test_suffix;
	SetPerconaXLogRecordCrypt(&test_crypt);
}
