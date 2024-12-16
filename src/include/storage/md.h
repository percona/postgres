/*-------------------------------------------------------------------------
 *
 * md.h
 *	  magnetic disk storage manager public interface declarations.
 *
 *
 * Portions Copyright (c) 1996-2024, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 * src/include/storage/md.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef MD_H
#define MD_H

#include "storage/block.h"
#include "storage/relfilelocator.h"
#include "storage/smgr.h"
#include "storage/sync.h"

#define MdSMgrName "md"

/* registration function for md storage manager */
extern void mdsmgr_register(void);
extern SMgrId MdSMgrId;

/* md storage manager functionality */
extern void mdinit(void);
extern void mdopen(SMgrRelation reln, SmgrChainIndex chain_index);
extern void mdclose(SMgrRelation reln, ForkNumber forknum, SmgrChainIndex chain_index);
extern void mdcreate(RelFileLocator relold, SMgrRelation reln, ForkNumber forknum, bool isRedo, SmgrChainIndex chain_index);
extern bool mdexists(SMgrRelation reln, ForkNumber forknum, SmgrChainIndex chain_index);
extern void mdunlink(RelFileLocatorBackend rlocator, ForkNumber forknum, bool isRedo, SmgrChainIndex chain_index);
extern void mdextend(SMgrRelation reln, ForkNumber forknum,
					 BlockNumber blocknum, const void *buffer, bool skipFsync, SmgrChainIndex chain_index);
extern void mdzeroextend(SMgrRelation reln, ForkNumber forknum,
						 BlockNumber blocknum, int nblocks, bool skipFsync, SmgrChainIndex chain_index);
extern bool mdprefetch(SMgrRelation reln, ForkNumber forknum,
					   BlockNumber blocknum, int nblocks, SmgrChainIndex chain_index);
extern void mdreadv(SMgrRelation reln, ForkNumber forknum, BlockNumber blocknum,
					void **buffers, BlockNumber nblocks, SmgrChainIndex chain_index);
extern void mdwritev(SMgrRelation reln, ForkNumber forknum,
					 BlockNumber blocknum,
					 const void **buffers, BlockNumber nblocks, bool skipFsync, SmgrChainIndex chain_index);
extern void mdwriteback(SMgrRelation reln, ForkNumber forknum,
						BlockNumber blocknum, BlockNumber nblocks, SmgrChainIndex chain_index);
extern BlockNumber mdnblocks(SMgrRelation reln, ForkNumber forknum, SmgrChainIndex chain_index);
extern void mdtruncate(SMgrRelation reln, ForkNumber forknum,
					   BlockNumber nblocks, SmgrChainIndex chain_index);
extern void mdimmedsync(SMgrRelation reln, ForkNumber forknum, SmgrChainIndex chain_index);
extern void mdregistersync(SMgrRelation reln, ForkNumber forknum, SmgrChainIndex chain_index);

extern void ForgetDatabaseSyncRequests(Oid dbid);
extern void DropRelationFiles(RelFileLocator *delrels, int ndelrels, bool isRedo);

/* md sync callbacks */
extern int	mdsyncfiletag(const FileTag *ftag, char *path);
extern int	mdunlinkfiletag(const FileTag *ftag, char *path);
extern bool mdfiletagmatches(const FileTag *ftag, const FileTag *candidate);

#endif							/* MD_H */
