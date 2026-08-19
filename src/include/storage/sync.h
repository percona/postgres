/*-------------------------------------------------------------------------
 *
 * sync.h
 *	  File synchronization management code.
 *
 * Portions Copyright (c) 1996-2025, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 * src/include/storage/sync.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef SYNC_H
#define SYNC_H

#include "storage/relfilelocator.h"

/*
 * Type of sync request.  These are used to manage the set of pending
 * requests to call a sync handler's sync or unlink functions at the next
 * checkpoint.
 */
typedef enum SyncRequestType
{
	SYNC_REQUEST,				/* schedule a call of sync function */
	SYNC_UNLINK_REQUEST,		/* schedule a call of unlink function */
	SYNC_FORGET_REQUEST,		/* forget all calls for a tag */
	SYNC_FILTER_REQUEST,		/* forget all calls satisfying match fn */
} SyncRequestType;

/*
 * Which set of functions to use to handle a given request.  Built-in
 * handlers occupy the fixed enum values below; extensions register
 * additional handlers via register_sync_handler() during
 * shared_preload_libraries initialization and receive IDs starting
 * at SYNC_HANDLER_FIRST_DYNAMIC. The values of the built-in
 * enumerators must match the order in which InitSync() pre-registers
 * the corresponding SyncOps structs in sync.c.
 */
typedef enum SyncRequestHandler
{
	SYNC_HANDLER_MD = 0,
	SYNC_HANDLER_CLOG,
	SYNC_HANDLER_COMMIT_TS,
	SYNC_HANDLER_MULTIXACT_OFFSET,
	SYNC_HANDLER_MULTIXACT_MEMBER,

	/* Extensions' dynamic handler IDs start here. */
	SYNC_HANDLER_FIRST_DYNAMIC,

	/*
	 * Sentinel for "no handler": fits in int16, outside the valid ID range so
	 * it cannot be confused with any registered handler.
	 */
	SYNC_HANDLER_NONE = -1,
} SyncRequestHandler;

#define SYNC_HANDLER_MAX	INT16_MAX

/*
 * A tag identifying a file.  Currently it has the members required for md.c's
 * usage, but sync.c has no knowledge of the internal structure, and it is
 * liable to change as required by future handlers.
 */
typedef struct FileTag
{
	int16		handler;		/* SyncRequestHandler value, saving space */
	int16		forknum;		/* ForkNumber, saving space */
	RelFileLocator rlocator;
	uint64		segno;
} FileTag;

/*
 * Dispatch table entry for a sync handler.  Public so extensions can
 * define their own SyncOps and pass them to register_sync_handler().
 *
 * sync_syncfiletag is required.  sync_unlinkfiletag and
 * sync_filetagmatches may be NULL if the handler does not support
 * SYNC_UNLINK_REQUEST or SYNC_FILTER_REQUEST respectively, matching
 * the pattern of the built-in CLOG/commit_ts/multixact handlers which
 * only define sync_syncfiletag.
 */
typedef struct SyncOps
{
	int			(*sync_syncfiletag) (const FileTag *ftag, char *path);
	int			(*sync_unlinkfiletag) (const FileTag *ftag, char *path);
	bool		(*sync_filetagmatches) (const FileTag *ftag,
										const FileTag *candidate);
} SyncOps;

extern void InitSyncHandlers(void);
extern void InitSync(void);
extern void SyncPreCheckpoint(void);
extern void SyncPostCheckpoint(void);
extern void ProcessSyncRequests(void);
extern void RememberSyncRequest(const FileTag *ftag, SyncRequestType type);
extern bool RegisterSyncRequest(const FileTag *ftag, SyncRequestType type,
								bool retryOnError);

/*
 * Register a custom sync handler.  Returns the assigned handler ID
 * which the extension stores in FileTag.handler when queueing sync
 * requests via RegisterSyncRequest().
 *
 * MUST be called during shared_preload_libraries initialization
 * (before process_shared_preload_libraries_done is set); later calls
 * raise FATAL.  `name` is used for error messages and is pstrdup'd
 * into TopMemoryContext by the caller; callers do not need to keep
 * the buffer alive.
 *
 * `ops->sync_syncfiletag` is required; the other two pointers may
 * be NULL if the handler does not participate in SYNC_UNLINK_REQUEST
 * or SYNC_FILTER_REQUEST flows.
 *
 * The returned ID is stable for the lifetime of the postmaster.
 * Sync requests live only in the checkpointer's in-memory pendingOps
 * hash table (they are not persisted across restarts), so there is
 * no cross-restart stability requirement beyond the same
 * shared_preload_libraries order that smgr_register() already relies
 * on.
 */
extern int16 register_sync_handler(const SyncOps *ops, const char *name);

#endif							/* SYNC_H */
