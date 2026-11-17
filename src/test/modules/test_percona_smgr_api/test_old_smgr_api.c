/*--------------------------------------------------------------------------
 *
 * test_old_smgr_api.c
 *		Extension using the upstream signatures of smgrcreate,
 *		RelationCreateStorage and index_create, like third party extensions
 *		built against upstream headers do.
 *
 * Copyright (c) 2026, Percona LLC and/or its affiliates
 *
 * IDENTIFICATION
 *		src/test/modules/test_percona_smgr_api/test_old_smgr_api.c
 *
 * -------------------------------------------------------------------------
 */
#include "postgres.h"

#include "access/heapam.h"
#include "access/multixact.h"
#include "access/tableam.h"
#include "catalog/index.h"
#include "catalog/pg_am_d.h"
#include "catalog/storage.h"
#include "catalog/storage_xlog.h"
#include "commands/defrem.h"
#include "common/relpath.h"
#include "fmgr.h"
#include "nodes/makefuncs.h"
#include "storage/smgr.h"
#include "utils/builtins.h"
#include "utils/lsyscache.h"
#include "utils/rel.h"

PG_MODULE_MAGIC;

static TableAmRoutine old_api_heap_methods;

/* Same as heapam_relation_set_new_filelocator, using the old API */
static void
old_api_relation_set_new_filelocator(Relation rel,
									 const RelFileLocator *newrlocator,
									 char persistence,
									 TransactionId *freezeXid,
									 MultiXactId *minmulti)
{
	SMgrRelation srel;

	*freezeXid = RecentXmin;
	*minmulti = GetOldestMultiXactId();

	srel = RelationCreateStorage(*newrlocator, persistence, true);

	if (persistence == RELPERSISTENCE_UNLOGGED)
	{
		smgrcreate(srel, INIT_FORKNUM, false);
		log_smgrcreate(newrlocator, INIT_FORKNUM);
	}

	smgrclose(srel);
}

PG_FUNCTION_INFO_V1(old_api_heap_handler);
Datum
old_api_heap_handler(PG_FUNCTION_ARGS)
{
	if (old_api_heap_methods.type == 0)
	{
		old_api_heap_methods = *GetHeapamTableAmRoutine();
		old_api_heap_methods.relation_set_new_filelocator =
			old_api_relation_set_new_filelocator;
	}

	PG_RETURN_POINTER(&old_api_heap_methods);
}

PG_FUNCTION_INFO_V1(old_api_smgrcreate);
Datum
old_api_smgrcreate(PG_FUNCTION_ARGS)
{
	Oid			relid = PG_GETARG_OID(0);
	char	   *forkname = text_to_cstring(PG_GETARG_TEXT_PP(1));
	ForkNumber	forknum = forkname_to_number(forkname);
	Relation	rel;
	SMgrRelation srel;

	rel = relation_open(relid, AccessExclusiveLock);
	srel = RelationGetSmgr(rel);

	if (smgrexists(srel, forknum))
		elog(ERROR, "fork \"%s\" of relation \"%s\" already exists",
			 forkname, RelationGetRelationName(rel));

	smgrcreate(srel, forknum, false);

	relation_close(rel, NoLock);

	PG_RETURN_VOID();
}

PG_FUNCTION_INFO_V1(old_api_index_create);
Datum
old_api_index_create(PG_FUNCTION_ARGS)
{
	Oid			relid = PG_GETARG_OID(0);
	char	   *indexname = text_to_cstring(PG_GETARG_TEXT_PP(1));
	char	   *colname = text_to_cstring(PG_GETARG_TEXT_PP(2));
	Relation	rel;
	AttrNumber	attnum;
	Oid			atttype;
	Oid			collation;
	Oid			opclass;
	int16		coloption = 0;
	IndexInfo  *indexInfo;
	Oid			indexoid;

	rel = table_open(relid, ShareLock);

	attnum = get_attnum(relid, colname);
	if (attnum == InvalidAttrNumber)
		elog(ERROR, "column \"%s\" does not exist", colname);

	atttype = get_atttype(relid, attnum);
	collation = get_typcollation(atttype);
	opclass = GetDefaultOpClass(atttype, BTREE_AM_OID);
	if (!OidIsValid(opclass))
		elog(ERROR, "no default btree operator class for column \"%s\"", colname);

	indexInfo = makeIndexInfo(1, 1, BTREE_AM_OID, NIL, NIL,
							  false, false, true, false, false, false);
	indexInfo->ii_IndexAttrNumbers[0] = attnum;

	indexoid = index_create(rel, indexname, InvalidOid, InvalidOid, InvalidOid,
							InvalidRelFileNumber, indexInfo,
							list_make1(colname), BTREE_AM_OID,
							rel->rd_rel->reltablespace,
							&collation, &opclass, NULL, &coloption, NULL,
							(Datum) 0, 0, 0, false, false, NULL);

	table_close(rel, NoLock);

	PG_RETURN_OID(indexoid);
}
