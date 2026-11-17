/*--------------------------------------------------------------------------
 *
 * test_new_smgr_api.c
 *		Preloaded library disabling the upstream signatures of smgrcreate,
 *		RelationCreateStorage and index_create, the same way pg_tde does.
 *
 * Copyright (c) 2026, Percona LLC and/or its affiliates
 *
 * IDENTIFICATION
 *		src/test/modules/test_percona_smgr_api/test_new_smgr_api.c
 *
 * -------------------------------------------------------------------------
 */
#include "postgres.h"

#include "fmgr.h"
#include "miscadmin.h"
#include "storage/smgr.h"

PG_MODULE_MAGIC;

void
_PG_init(void)
{
	if (!process_shared_preload_libraries_in_progress)
		elog(ERROR, "test_new_smgr_api must be loaded via \"shared_preload_libraries\"");

	percona_allow_upstream_smgr_api = false;
}
