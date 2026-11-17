/* src/test/modules/test_percona_smgr_api/test_old_smgr_api--1.0.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION test_old_smgr_api" to load this file. \quit

CREATE FUNCTION old_api_heap_handler(internal)
RETURNS table_am_handler
AS 'MODULE_PATHNAME'
LANGUAGE C;

CREATE ACCESS METHOD old_api_heap TYPE TABLE HANDLER old_api_heap_handler;

CREATE FUNCTION old_api_smgrcreate(rel regclass, fork text)
RETURNS void
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE FUNCTION old_api_index_create(rel regclass, indexname text, colname text)
RETURNS regclass
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;
