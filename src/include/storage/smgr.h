/*-------------------------------------------------------------------------
 *
 * smgr.h
 *	  storage manager switch public interface declarations.
 *
 *
 * Portions Copyright (c) 1996-2025, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 * src/include/storage/smgr.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef SMGR_H
#define SMGR_H

#include "lib/ilist.h"
#include "storage/block.h"
#include "storage/relfilelocator.h"

typedef uint8 SMgrId;

typedef uint8 SmgrChainIndex;

#define MAX_SMGR_CHAIN 15

typedef struct
{
	SMgrId		chain[MAX_SMGR_CHAIN];	/* storage manager selector */
	uint8		size;
} SMgrChain;

extern PGDLLIMPORT SMgrChain storage_manager_chain;

/*
 * smgr.c maintains a table of SMgrRelation objects, which are essentially
 * cached file handles.  An SMgrRelation is created (if not already present)
 * by smgropen(), and destroyed by smgrdestroy().  Note that neither of these
 * operations imply I/O, they just create or destroy a hashtable entry.  (But
 * smgrdestroy() may release associated resources, such as OS-level file
 * descriptors.)
 *
 * An SMgrRelation may be "pinned", to prevent it from being destroyed while
 * it's in use.  We use this to prevent pointers in relcache to smgr from being
 * invalidated.  SMgrRelations that are not pinned are deleted at end of
 * transaction.
 */
typedef struct SMgrRelationData
{
	/* rlocator is the hashtable lookup key, so it must be first! */
	RelFileLocatorBackend smgr_rlocator;	/* relation physical identifier */

	/*
	 * The following fields are reset to InvalidBlockNumber upon a cache flush
	 * event, and hold the last known size for each fork.  This information is
	 * currently only reliable during recovery, since there is no cache
	 * invalidation for fork extension.
	 */
	BlockNumber smgr_targblock; /* current insertion target block */
	BlockNumber smgr_cached_nblocks[MAX_FORKNUM + 1];	/* last known size */

	/* additional public fields may someday exist here */

	/*
	 * Fields below here are intended to be private to smgr.c and its
	 * submodules.  Do not touch them from elsewhere.
	 */
	SMgrChain	smgr_chain;		/* selected storage manager chain */

	/*
	 * Pinning support.  If unpinned (ie. pincount == 0), 'node' is a list
	 * link in list of all unpinned SMgrRelations.
	 */
	int			pincount;
	dlist_node	node;
} SMgrRelationData;

typedef SMgrRelationData *SMgrRelation;

#define SmgrIsTemp(smgr) \
	RelFileLocatorBackendIsTemp((smgr)->smgr_rlocator)

#define SMGR_CHAIN_TAIL 1
#define SMGR_CHAIN_MODIFIER 2

/*
 * This struct of function pointers defines the API between smgr.c and
 * any individual storage manager module.  Note that smgr subfunctions are
 * generally expected to report problems via elog(ERROR).  An exception is
 * that smgr_unlink should use elog(WARNING), rather than erroring out,
 * because we normally unlink relations during post-commit/abort cleanup,
 * and so it's too late to raise an error.  Also, various conditions that
 * would normally be errors should be allowed during bootstrap and/or WAL
 * recovery --- see comments in md.c for details.
 */
typedef struct f_smgr
{
	const char *name;
	int			chain_position;
	void		(*smgr_init) (void);	/* may be NULL */
	void		(*smgr_shutdown) (void);	/* may be NULL */
	void		(*smgr_open) (SMgrRelation reln, SmgrChainIndex chain_index);
	void		(*smgr_close) (SMgrRelation reln, ForkNumber forknum, SmgrChainIndex chain_index);
	void		(*smgr_create) (RelFileLocator relold, SMgrRelation reln, ForkNumber forknum,
								bool isRedo, SmgrChainIndex chain_index);
	bool		(*smgr_exists) (SMgrRelation reln, ForkNumber forknum, SmgrChainIndex chain_index);
	void		(*smgr_unlink) (RelFileLocatorBackend rlocator, ForkNumber forknum,
								bool isRedo, SmgrChainIndex chain_index);
	void		(*smgr_extend) (SMgrRelation reln, ForkNumber forknum,
								BlockNumber blocknum, const void *buffer, bool skipFsync, SmgrChainIndex chain_index);
	void		(*smgr_zeroextend) (SMgrRelation reln, ForkNumber forknum,
									BlockNumber blocknum, int nblocks, bool skipFsync, SmgrChainIndex chain_index);
	bool		(*smgr_prefetch) (SMgrRelation reln, ForkNumber forknum,
								  BlockNumber blocknum, int nblocks, SmgrChainIndex chain_index);
	uint32		(*smgr_maxcombine) (SMgrRelation reln, ForkNumber forknum,
									BlockNumber blocknum, SmgrChainIndex chain_index);
	void		(*smgr_readv) (SMgrRelation reln, ForkNumber forknum,
							   BlockNumber blocknum,
							   void **buffers, BlockNumber nblocks, SmgrChainIndex chain_index);
	void		(*smgr_writev) (SMgrRelation reln, ForkNumber forknum,
								BlockNumber blocknum,
								const void **buffers, BlockNumber nblocks,
								bool skipFsync, SmgrChainIndex chain_index);
	void		(*smgr_writeback) (SMgrRelation reln, ForkNumber forknum,
								   BlockNumber blocknum, BlockNumber nblocks, SmgrChainIndex chain_index);
	BlockNumber (*smgr_nblocks) (SMgrRelation reln, ForkNumber forknum, SmgrChainIndex chain_index);
	void		(*smgr_truncate) (SMgrRelation reln, ForkNumber forknum,
								  BlockNumber old_blocks, BlockNumber nblocks, SmgrChainIndex chain_index);
	void		(*smgr_immedsync) (SMgrRelation reln, ForkNumber forknum, SmgrChainIndex chain_index);
	void		(*smgr_registersync) (SMgrRelation reln, ForkNumber forknum, SmgrChainIndex chain_index);
} f_smgr;

extern SMgrId smgr_register(const f_smgr *smgr, Size smgrrelation_size);
extern SMgrId smgr_lookup(const char *name);

extern f_smgr *smgrsw;

extern void smgrinit(void);
extern SMgrRelation smgropen(RelFileLocator rlocator, ProcNumber backend);
extern bool smgrexists(SMgrRelation reln, ForkNumber forknum);
extern void smgrpin(SMgrRelation reln);
extern void smgrunpin(SMgrRelation reln);
extern void smgrclose(SMgrRelation reln);
extern void smgrdestroyall(void);
extern void smgrrelease(SMgrRelation reln);
extern void smgrreleaseall(void);
extern void smgrreleaserellocator(RelFileLocatorBackend rlocator);
extern void smgrcreate(RelFileLocator relold, SMgrRelation reln, ForkNumber forknum, bool isRedo);
extern void smgrdosyncall(SMgrRelation *rels, int nrels);
extern void smgrdounlinkall(SMgrRelation *rels, int nrels, bool isRedo);
extern void smgrextend(SMgrRelation reln, ForkNumber forknum,
					   BlockNumber blocknum, const void *buffer, bool skipFsync);
extern void smgrzeroextend(SMgrRelation reln, ForkNumber forknum,
						   BlockNumber blocknum, int nblocks, bool skipFsync);
extern bool smgrprefetch(SMgrRelation reln, ForkNumber forknum,
						 BlockNumber blocknum, int nblocks);
extern uint32 smgrmaxcombine(SMgrRelation reln, ForkNumber forknum,
							 BlockNumber blocknum);
extern void smgrreadv(SMgrRelation reln, ForkNumber forknum,
					  BlockNumber blocknum,
					  void **buffers, BlockNumber nblocks);
extern void smgrwritev(SMgrRelation reln, ForkNumber forknum,
					   BlockNumber blocknum,
					   const void **buffers, BlockNumber nblocks,
					   bool skipFsync);
extern void smgrwriteback(SMgrRelation reln, ForkNumber forknum,
						  BlockNumber blocknum, BlockNumber nblocks);
extern BlockNumber smgrnblocks(SMgrRelation reln, ForkNumber forknum);
extern BlockNumber smgrnblocks_cached(SMgrRelation reln, ForkNumber forknum);
extern void smgrtruncate(SMgrRelation reln, ForkNumber *forknum, int nforks,
						 BlockNumber *old_nblocks,
						 BlockNumber *nblocks);
extern void smgrimmedsync(SMgrRelation reln, ForkNumber forknum);
extern void smgrregistersync(SMgrRelation reln, ForkNumber forknum);
extern void AtEOXact_SMgr(void);
extern bool ProcessBarrierSmgrRelease(void);

extern void
			smgr_open_next(SMgrRelation reln, SmgrChainIndex chain_index);
extern void
			smgr_close_next(SMgrRelation reln, ForkNumber forknum, SmgrChainIndex chain_index);
extern bool
			smgr_exists_next(SMgrRelation reln, ForkNumber forknum, SmgrChainIndex chain_index);
extern void
			smgr_create_next(RelFileLocator relold, SMgrRelation reln, ForkNumber forknum, bool isRedo, SmgrChainIndex chain_index);
extern void
			smgr_immedsync_next(SMgrRelation reln, ForkNumber forknum, SmgrChainIndex chain_index);
extern void
			smgr_unlink_next(SMgrRelation reln, RelFileLocatorBackend rlocator, ForkNumber forknum, bool isRedo, SmgrChainIndex chain_index);
extern void
			smgr_extend_next(SMgrRelation reln, ForkNumber forknum, BlockNumber blocknum,
							 const void *buffer, bool skipFsync, SmgrChainIndex chain_index);
extern void
			smgr_zeroextend_next(SMgrRelation reln, ForkNumber forknum, BlockNumber blocknum,
								 int nblocks, bool skipFsync, SmgrChainIndex chain_index);
extern bool
			smgr_prefetch_next(SMgrRelation reln, ForkNumber forknum, BlockNumber blocknum,
							   int nblocks, SmgrChainIndex chain_index);
extern uint32
			smgr_maxcombine_next(SMgrRelation reln, ForkNumber forknum,
								 BlockNumber blocknum, SmgrChainIndex chain_index);
extern void
			smgr_readv_next(SMgrRelation reln, ForkNumber forknum, BlockNumber blocknum,
							void **buffers, BlockNumber nblocks, SmgrChainIndex chain_index);
extern void
			smgr_writev_next(SMgrRelation reln, ForkNumber forknum, BlockNumber blocknum,
							 const void **buffers, BlockNumber nblocks, bool skipFsync, SmgrChainIndex chain_index);
extern void
			smgr_writeback_next(SMgrRelation reln, ForkNumber forknum, BlockNumber blocknum,
								BlockNumber nblocks, SmgrChainIndex chain_index);
extern BlockNumber
			smgr_nblocks_next(SMgrRelation reln, ForkNumber forknum, SmgrChainIndex chain_index);
extern void
			smgr_truncate_next(SMgrRelation reln, ForkNumber forknum, BlockNumber curnblk, BlockNumber nblocks, SmgrChainIndex chain_index);
extern void
			smgr_registersync_next(SMgrRelation reln, ForkNumber forknum, SmgrChainIndex chain_index);

static inline void
smgrread(SMgrRelation reln, ForkNumber forknum, BlockNumber blocknum,
		 void *buffer)
{
	smgrreadv(reln, forknum, blocknum, &buffer, 1);
}

static inline void
smgrwrite(SMgrRelation reln, ForkNumber forknum, BlockNumber blocknum,
		  const void *buffer, bool skipFsync)
{
	smgrwritev(reln, forknum, blocknum, &buffer, 1, skipFsync);
}

#endif							/* SMGR_H */
