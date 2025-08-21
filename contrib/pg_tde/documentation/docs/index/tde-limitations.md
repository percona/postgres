# Limitations of pg_tde

Limitations of `pg_tde` {{release}}:

* PostgreSQL’s internal system tables, which include statistics and metadata, are not encrypted.
* `pg_createsubscriber` is not supported.
* Temporary files created when queries exceed `work_mem` are not encrypted. These files may persist if the query runs for a long time or the server crashes which can expose sensitive data in plaintext on disk.

## WAL tool compatibility (limited support)

The following tools and extensions in Percona Distribution for PostgreSQL have been tested and verified to work with `pg_tde` WAL encryption:

??? note "Click to expand"
    * Patroni
    * `pg_basebackup` (with `--wal-method=stream` or `--wal-method=none`), for details on using `pg_basebackup` with WAL encryption, see [Backup with WAL encryption enabled](../how-to/backup-wal-enabled.md)
    * `pg_resetwal`
    * `pg_rewind`
    * `pg_upgrade`
    * `pg_waldump`
    * pgBackRest

## Next steps

Check which PostgreSQL versions and deployment types are compatible with `pg_tde` before planning your installation.

[View the versions and supported deployments :material-arrow-right:](supported-versions.md){.md-button}

Begin the installation process when you're ready to set up encryption.

[Start installing `pg_tde`](../install.md){.md-button}
