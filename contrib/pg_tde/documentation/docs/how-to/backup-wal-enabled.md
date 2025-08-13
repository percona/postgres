# Backing up with WAL encryption enabled

When taking a backup from a server with WAL encryption enabled, you must copy the `pg_tde` directory, specifically the `wal_keys` and `1664_providers` files, from the source server to the backup destination before running `pg_basebackup`.

Without these files:

1. Part of the WAL in the backup may be unencrypted
2. The server might fail to start from such a backup

If WAL encryption is disabled and has never been used, copying the `pg_tde` directory is unnecessary.

!!! warning

    Do not restart the source server between copying `pg_tde` and running `pg_basebackup`.
    Restarting the server generates a new key, invalidating the previously copied `pg_tde/wal_keys` file.  
    The backup will still complete, but the WAL data it contains will be corrupted.
