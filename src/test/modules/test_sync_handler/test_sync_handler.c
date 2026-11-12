/*--------------------------------------------------------------------------
 *
 * test_sync_handler.c
 *		Minimal extension exercising register_sync_handler() + dispatch.
 *
 * This module demonstrates the sync.c extensibility API by registering a
 * trivial SyncOps during _PG_init(), exposing SQL-callable helpers to
 * queue FileTags for the registered handler, and tracking how many times
 * the handler's sync_syncfiletag callback is invoked.
 *
 * Because sync_syncfiletag runs in the checkpointer process but
 * test_sync_handler_count() runs in a regular backend, the call counter
 * lives in shared memory via GetNamedDSMSegment().
 *
 * The TAP test in t/001_basic.pl uses this module to verify:
 *   - register_sync_handler() returns an ID >= SYNC_HANDLER_FIRST_DYNAMIC
 *   - Queued FileTags round-trip through the checkpointer and land in
 *     the registered sync_syncfiletag callback at CHECKPOINT time
 *   - Identical FileTags coalesce via HASH_BLOBS deduplication in
 *     pendingOps (N duplicates -> 1 callback)
 *   - Distinct FileTags produce distinct callbacks
 *   - Idle checkpoints do not re-dispatch (cycle_ctr skip)
 *
 * Copyright (c) 2026, PostgreSQL Global Development Group
 *
 * IDENTIFICATION
 *		src/test/modules/test_sync_handler/test_sync_handler.c
 *
 *--------------------------------------------------------------------------
 */
#include "postgres.h"

#include "fmgr.h"
#include "miscadmin.h"
#include "pg_config.h"
#include "port/atomics.h"
#include "storage/dsm_registry.h"
#include "storage/sync.h"
#include "utils/builtins.h"

PG_MODULE_MAGIC;

void		_PG_init(void);

typedef struct TshSharedState
{
	pg_atomic_uint64 call_count;
} TshSharedState;

static int16 tsh_handler_id = -1;
static TshSharedState *tsh_shared = NULL;

/*
 * GetNamedDSMSegment's init_callback signature gained an extra `arg`
 * parameter in PG 19devel. Provide both shapes so the test module is
 * buildable across 18 and 19.
 */
#if PG_VERSION_NUM >= 190000
static void
tsh_init_shmem(void *ptr, void *arg)
#else
static void
tsh_init_shmem(void *ptr)
#endif
{
	TshSharedState *state = (TshSharedState *) ptr;

	pg_atomic_init_u64(&state->call_count, 0);
}

static void
tsh_attach_shmem(void)
{
	bool		found;

	if (tsh_shared != NULL)
		return;
#if PG_VERSION_NUM >= 190000
	tsh_shared = GetNamedDSMSegment("test_sync_handler",
									sizeof(TshSharedState),
									tsh_init_shmem,
									&found,
									NULL);
#else
	tsh_shared = GetNamedDSMSegment("test_sync_handler",
									sizeof(TshSharedState),
									tsh_init_shmem,
									&found);
#endif
}

static int
test_sync_syncfiletag(const FileTag *ftag, char *path)
{
	/*
	 * This runs in the checkpointer process. Attach to the shared memory
	 * segment the first time we're called so that counter increments are
	 * visible to the backend that queries test_sync_handler_count().
	 */
	tsh_attach_shmem();
	pg_atomic_fetch_add_u64(&tsh_shared->call_count, 1);

	if (path != NULL)
		snprintf(path, MAXPGPATH, "test_sync_handler:seg%llu",
				 (unsigned long long) ftag->segno);
	return 0;
}

static int
test_sync_unlinkfiletag(const FileTag *ftag, char *path)
{
	if (path != NULL)
		snprintf(path, MAXPGPATH, "test_sync_handler:unlink");
	return 0;
}

static bool
test_sync_filetagmatches(const FileTag *ftag, const FileTag *candidate)
{
	/*
	 * Match on dbOid, mirroring md.c's DROP DATABASE semantics. The test
	 * doesn't exercise the filter path today, but the callback is defined so
	 * extensions can use this module as a copy-paste starting point.
	 */
	return ftag->rlocator.dbOid == candidate->rlocator.dbOid;
}

static const SyncOps test_sync_ops = {
	.sync_syncfiletag = test_sync_syncfiletag,
	.sync_unlinkfiletag = test_sync_unlinkfiletag,
	.sync_filetagmatches = test_sync_filetagmatches,
};

void
_PG_init(void)
{
	tsh_handler_id = register_sync_handler(&test_sync_ops, "test_sync_handler");
	elog(LOG, "test_sync_handler: registered as id %d",
		 (int) tsh_handler_id);
}

PG_FUNCTION_INFO_V1(test_sync_handler_id);
Datum
test_sync_handler_id(PG_FUNCTION_ARGS)
{
	PG_RETURN_INT32((int32) tsh_handler_id);
}

PG_FUNCTION_INFO_V1(test_sync_handler_register);
Datum
test_sync_handler_register(PG_FUNCTION_ARGS)
{
	int64		seg = PG_GETARG_INT64(0);
	FileTag		tag;

	if (tsh_handler_id < 0)
		ereport(ERROR,
				(errcode(ERRCODE_INTERNAL_ERROR),
				 errmsg("sync handler was not registered during module initialization")));

	/*
	 * Mandatory memset: pendingOps uses HASH_BLOBS which hashes every byte of
	 * the FileTag. Uninitialized padding would break coalescing.
	 */
	memset(&tag, 0, sizeof(FileTag));
	tag.handler = tsh_handler_id;
	tag.forknum = 0;
	tag.rlocator.spcOid = 1;
	tag.rlocator.dbOid = MyDatabaseId;
	tag.rlocator.relNumber = 1;
	tag.segno = (uint64) seg;

	if (!RegisterSyncRequest(&tag, SYNC_REQUEST, true /* retryOnError */ ))
		ereport(ERROR,
				(errcode(ERRCODE_INTERNAL_ERROR),
				 errmsg("could not register sync request")));

	PG_RETURN_VOID();
}

PG_FUNCTION_INFO_V1(test_sync_handler_count);
Datum
test_sync_handler_count(PG_FUNCTION_ARGS)
{
	tsh_attach_shmem();
	PG_RETURN_INT64((int64) pg_atomic_read_u64(&tsh_shared->call_count));
}
