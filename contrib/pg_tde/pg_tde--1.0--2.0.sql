CREATE FUNCTION pg_tde_is_wal_record_encrypted(lsn pg_lsn, tli integer DEFAULT 0)
RETURNS BOOLEAN
LANGUAGE C
AS 'MODULE_PATHNAME';
REVOKE ALL ON FUNCTION pg_tde_is_wal_record_encrypted(pg_lsn, integer) FROM PUBLIC;
