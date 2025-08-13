/*
 * Main file: setup GUCs, shared memory, hooks and other general-purpose
 * routines.
 */

#include "postgres.h"

#include "access/tableam.h"
#include "access/xlog.h"
#include "access/xloginsert.h"
#include "funcapi.h"
#include "miscadmin.h"
#include "storage/ipc.h"
#include "storage/lwlock.h"
#include "storage/shmem.h"
#include "utils/builtins.h"
#include "utils/percona.h"
#include "utils/pg_lsn.h"

#include "access/pg_tde_tdemap.h"
#include "access/pg_tde_xlog.h"
#include "access/pg_tde_xlog_smgr.h"
#include "access/pg_tde_xlog_keys.h"
#include "catalog/tde_global_space.h"
#include "catalog/tde_principal_key.h"
#include "encryption/enc_aes.h"
#include "keyring/keyring_api.h"
#include "keyring/keyring_file.h"
#include "keyring/keyring_kmip.h"
#include "keyring/keyring_vault.h"
#include "pg_tde.h"
#include "pg_tde_event_capture.h"
#include "pg_tde_guc.h"
#include "smgr/pg_tde_smgr.h"

PG_MODULE_MAGIC;

#define PG_TDE_LIST_WAL_KEYS_RANGES_COLS 4

static void pg_tde_init_data_dir(void);

static shmem_startup_hook_type prev_shmem_startup_hook = NULL;
static shmem_request_hook_type prev_shmem_request_hook = NULL;

PG_FUNCTION_INFO_V1(pg_tde_extension_initialize);
PG_FUNCTION_INFO_V1(pg_tde_version);
PG_FUNCTION_INFO_V1(pg_tdeam_handler);
PG_FUNCTION_INFO_V1(pg_tde_is_wal_record_encrypted);
PG_FUNCTION_INFO_V1(pg_tde_get_wal_encryption_ranges);

static void
tde_shmem_request(void)
{
	Size		sz = 0;

	sz = add_size(sz, PrincipalKeyShmemSize());
	sz = add_size(sz, TDEXLogEncryptStateSize());

	if (prev_shmem_request_hook)
		prev_shmem_request_hook();

	RequestAddinShmemSpace(sz);
	RequestNamedLWLockTranche(TDE_TRANCHE_NAME, TDE_LWLOCK_COUNT);
	ereport(LOG, errmsg("tde_shmem_request: requested %ld bytes", sz));
}

static void
tde_shmem_startup(void)
{
	if (prev_shmem_startup_hook)
		prev_shmem_startup_hook();

	LWLockAcquire(AddinShmemInitLock, LW_EXCLUSIVE);

	KeyProviderShmemInit();
	PrincipalKeyShmemInit();
	TDEXLogShmemInit();
	TDEXLogSmgrInit();
	TDEXLogSmgrInitWrite(EncryptXLog);

	LWLockRelease(AddinShmemInitLock);
}

void
_PG_init(void)
{
	if (!process_shared_preload_libraries_in_progress)
	{
		/*
		 * psql/pg_restore continue on error by default, and change access
		 * methods using set default_table_access_method. This error needs to
		 * be FATAL and close the connection, otherwise these tools will
		 * continue execution and create unencrypted tables when the intention
		 * was to make them encrypted.
		 */
		elog(FATAL, "pg_tde can only be loaded at server startup. Restart required.");
	}

	check_percona_api_version();

	pg_tde_init_data_dir();
	AesInit();
	TdeGucInit();
	TdeEventCaptureInit();
	InstallFileKeyring();
	InstallVaultV2Keyring();
	InstallKmipKeyring();
	RegisterTdeRmgr();
	RegisterStorageMgr();

	prev_shmem_request_hook = shmem_request_hook;
	shmem_request_hook = tde_shmem_request;
	prev_shmem_startup_hook = shmem_startup_hook;
	shmem_startup_hook = tde_shmem_startup;
}

static void
extension_install(Oid databaseId)
{
	key_provider_startup_cleanup(databaseId);
	principal_key_startup_cleanup(databaseId);
}

Datum
pg_tde_extension_initialize(PG_FUNCTION_ARGS)
{
	XLogExtensionInstall xlrec;

	xlrec.database_id = MyDatabaseId;
	extension_install(xlrec.database_id);

	/*
	 * Also put this info in xlog, so we can replicate the same on the other
	 * side
	 */
	XLogBeginInsert();
	XLogRegisterData((char *) &xlrec, sizeof(XLogExtensionInstall));
	XLogInsert(RM_TDERMGR_ID, XLOG_TDE_INSTALL_EXTENSION);

	PG_RETURN_VOID();
}

void
extension_install_redo(XLogExtensionInstall *xlrec)
{
	extension_install(xlrec->database_id);
}

/* Creates a tde directory for internal files if not exists */
static void
pg_tde_init_data_dir(void)
{
	if (access(PG_TDE_DATA_DIR, F_OK) == -1)
	{
		if (MakePGDirectory(PG_TDE_DATA_DIR) < 0)
			ereport(ERROR,
					errcode_for_file_access(),
					errmsg("could not create tde directory \"%s\": %m",
						   PG_TDE_DATA_DIR));
	}
}

/* Returns package version */
Datum
pg_tde_version(PG_FUNCTION_ARGS)
{
	PG_RETURN_TEXT_P(cstring_to_text(PG_TDE_VERSION_STRING));
}

Datum
pg_tdeam_handler(PG_FUNCTION_ARGS)
{
	PG_RETURN_POINTER(GetHeapamTableAmRoutine());
}

/*
 * Returns true if the WAL record at the given LSN is encrypted.
 */
Datum
pg_tde_is_wal_record_encrypted(PG_FUNCTION_ARGS)
{
	XLogRecPtr	lsn = PG_GETARG_LSN(0);
	int			tli = PG_GETARG_INT32(1);
	WalLocation loc;
	WALKeyCacheRec *keys;

	if (tli == 0)
		tli = GetWALInsertionTimeLine();

	/* Load all keys for the given timeline */
	loc = (WalLocation)
	{
		.tli = tli,.lsn = 0
	};

	keys = pg_tde_fetch_wal_keys(loc);
	if (!keys)
		PG_RETURN_BOOL(false);

	loc.lsn = lsn;

	for (WALKeyCacheRec *curr_key = keys; curr_key != NULL; curr_key = curr_key->next)
	{
		if (wal_location_cmp(loc, curr_key->start) >= 0 &&
			wal_location_cmp(loc, curr_key->end) < 0)
			PG_RETURN_BOOL(curr_key->key.type == WAL_KEY_TYPE_ENCRYPTED);
	}

	PG_RETURN_BOOL(false);
}

/*
 * Returns WAL encryption ranges. WAL records within the LSN range are encrypted.
 */
Datum
pg_tde_get_wal_encryption_ranges(PG_FUNCTION_ARGS)
{
	Tuplestorestate *tupstore;
	TupleDesc	tupdesc;
	ReturnSetInfo *rsinfo = (ReturnSetInfo *) fcinfo->resultinfo;
	MemoryContext per_query_ctx;
	MemoryContext oldcontext;
	WALKeyCacheRec *keys;
	WalLocation loc = {.tli = 0,.lsn = 0};

	/* check to see if caller supports us returning a tuplestore */
	if (rsinfo == NULL || !IsA(rsinfo, ReturnSetInfo))
		ereport(ERROR,
				errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
				errmsg("set-valued function called in context that cannot accept a set"));
	if (!(rsinfo->allowedModes & SFRM_Materialize))
		ereport(ERROR,
				errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
				errmsg("materialize mode required, but it is not allowed in this context"));

	/* Switch into long-lived context to construct returned data structures */
	per_query_ctx = rsinfo->econtext->ecxt_per_query_memory;
	oldcontext = MemoryContextSwitchTo(per_query_ctx);

	/* Build a tuple descriptor for our result type */
	if (get_call_result_type(fcinfo, NULL, &tupdesc) != TYPEFUNC_COMPOSITE)
		elog(ERROR, "return type must be a row type");

	tupstore = tuplestore_begin_heap(true, false, work_mem);
	rsinfo->returnMode = SFRM_Materialize;
	rsinfo->setResult = tupstore;
	rsinfo->setDesc = tupdesc;

	MemoryContextSwitchTo(oldcontext);

	keys = pg_tde_fetch_wal_keys(loc);

	for (WALKeyCacheRec *curr_key = keys; curr_key != NULL; curr_key = curr_key->next)
	{
		Datum		values[PG_TDE_LIST_WAL_KEYS_RANGES_COLS] = {0};
		bool		nulls[PG_TDE_LIST_WAL_KEYS_RANGES_COLS] = {0};
		int			i = 0;

		if (curr_key->key.type != WAL_KEY_TYPE_ENCRYPTED)
			continue;

		values[i++] = Int64GetDatum(curr_key->start.tli);
		values[i++] = Int64GetDatum(curr_key->start.lsn);
		values[i++] = Int64GetDatum(curr_key->end.tli);
		values[i++] = Int64GetDatum(curr_key->end.lsn);

		tuplestore_putvalues(tupstore, tupdesc, values, nulls);
	}

	return (Datum) 0;
}
