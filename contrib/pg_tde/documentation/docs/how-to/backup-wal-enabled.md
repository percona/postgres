# Backup with WAL encryption enabled

To create a backup with WAL encryption enabled:

1. Copy the `pg_tde` directory, including the `wal_keys` and `1664_providers` files, and any external files referenced by your providers configuration (for example, certificate or key files).
2. Run:

    ```bash
    pg_basebackup -X stream -F p -E
    ```

    Where:

    - `-X stream` streams WAL in parallel with the base backup (default)
    - `-F p` writes the backup in plain format (default)
    - `-E` (or `--encrypt-wal`) enables WAL encryption and validates that the copied `pg_tde` and provider files are present and that the server key is accessible (required)

!!! note
    If the required `pg_tde` files or referenced provider files are missing, or the server key is not accessible, `pg_basebackup` will fail immediately without starting the backup.
