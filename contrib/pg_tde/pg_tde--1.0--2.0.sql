-- Function to check if a WAL record is encrypted
CREATE FUNCTION pg_tde_is_wal_record_encrypted(lsn pg_lsn, tli integer DEFAULT 0)
RETURNS BOOLEAN
LANGUAGE C
AS 'MODULE_PATHNAME';
REVOKE ALL ON FUNCTION pg_tde_is_wal_record_encrypted(pg_lsn, integer) FROM PUBLIC;

-- Function to get WAL encryption ranges
CREATE FUNCTION pg_tde_get_wal_encryption_ranges
    (OUT start_tli integer,
    OUT start_lsn pg_lsn,
    OUT end_tli integer,
    OUT end_lsn pg_lsn)
RETURNS SETOF RECORD
LANGUAGE C
AS 'MODULE_PATHNAME';
REVOKE ALL ON FUNCTION pg_tde_get_wal_encryption_ranges() FROM PUBLIC;
