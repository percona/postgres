/* src/test/modules/test_sync_handler/test_sync_handler--1.0.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION test_sync_handler" to load this file. \quit

CREATE FUNCTION test_sync_handler_id() RETURNS int4
  AS 'MODULE_PATHNAME', 'test_sync_handler_id' LANGUAGE C STRICT;

CREATE FUNCTION test_sync_handler_register(seg bigint) RETURNS void
  AS 'MODULE_PATHNAME', 'test_sync_handler_register' LANGUAGE C STRICT;

CREATE FUNCTION test_sync_handler_count() RETURNS bigint
  AS 'MODULE_PATHNAME', 'test_sync_handler_count' LANGUAGE C STRICT;
