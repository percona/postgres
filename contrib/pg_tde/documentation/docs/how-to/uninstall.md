# Uninstall pg_tde

If you no longer wish to use TDE in your deployment, you can remove the `pg_tde` extension. To do so, you must have superuser privileges, or database owner privileges in case you only want to remove it from a single database.

To uninstall `pg_tde`, follow these steps:

## 1. Drop the pg_tde extension from all databases

For all databases where the extensions is loaded you need to follow these steps. This also includes the template databases, in case `pg_tde` was previously enabled there.

1. Decrypt or drop encrypted tables:

    Before removing the extension, you must either **decrypt** or **drop** all encrypted tables:

    - To decrypt a table, run:

    ```sql
    ALTER TABLE <table name> SET ACCESS METHOD heap;
    ```

    - To discard data, drop the encrypted tables.

2. Drop the extension using the `DROP EXTENSION` command:

    ```sql
    DROP EXTENSION pg_tde;
    ```

    If there are any encrypted objects that were not previously decrypted or deleted, this command will fail and you have to follow the step above for these objects.

    Alternatively, to remove everything at once:

    ```sql
    DROP EXTENSION pg_tde CASCADE;
    ```

    !!! note
        The `DROP EXTENSION` command does not delete the underlying `pg_tde`-specific data files from disk.

## 2. Turn off WAL encryption

If you are using  WAL encryption it needs to be turned off before the pg_tde library can be uninstalled.

1. Run `ALTER SYSTEM SET pg_tde.wal_encrypt=off;`

2. Restart the `postgresql` cluster to apply the changes.

    * On Debian and Ubuntu:

       ```sh
       sudo systemctl restart postgresql
       ```

    * On RHEL and derivatives

       ```sh
       sudo systemctl restart postgresql-17

## 3. Uninstall the pg_tde shared library

!!! warning
    This process removes the extension, but does not decrypt data automatically. Only uninstall the shared library after all encrypted data **has been removed or decrypted** and WAL encryption **has been disabled**.

!!! note
    Encrypted WAL pages will not be decrypted, so any postgres cluster needing to read them will need the `pg_tde` library loaded, and the WAL encryption keys used available.

At this point, the shared library is still loaded but inactive. Follow these steps to completely uninstall it.

1. Run `SHOW shared_preload_libraries` to view the current configuration of preloaded libraries.
    Example:
    ```
    postgres=# SHOW shared_preload_libraries;
            shared_preload_libraries
    -----------------------------------------
    pg_stat_statements,pg_tde,auto_explain
    (1 row)

    postgres=#
    ```
2. Remove `pg_tde` from the list and apply the new setting using `ALTER SYSTEM SET shared_preload_libraries=<your list of libraries>`
    Example:
    ```
    postgres=# ALTER SYSTEM SET shared_preload_libraries=pg_stat_statements,auto_explain;
    ALTER SYSTEM
    postgres=#
    ```
    !!! note
        Your list of libraries will most likely be different than in this example.

    !!! note
        If `pg_tde` is the only shared library in the list, and this is set using `postgresql.conf`, there is no way to disable it using `ALTER SYSTEM SET ...`. Instead remove the `shared_preload_libraries` line from `postgresql.conf` and then run `ALTER SYSTEM RESET shared_preload_libraries;`.

3. Restart the `postgresql` cluster to apply the changes.

    * On Debian and Ubuntu:

       ```sh
       sudo systemctl restart postgresql
       ```

    * On RHEL and derivatives

       ```sh
       sudo systemctl restart postgresql-17
       ```

## 4. (optional) Cleanup

    At this point it is safe to remove any configuration related to pg_tde from `postgresql.conf` and `postgresql.auto.conf`. These configuration options have the prefix `pg_tde.`

## Potential issues
    If WAL encryption wasn't fully disabled before the `pg_tde` library was uninstalled you may get an error message like this when trying to restart the cluster:

    ```
    2025-04-01 17:12:50.607 CEST [496385] PANIC:  could not locate a valid checkpoint record at 0/17B2580
    ```

    If this happens, re-add `pg_tde` to `shared_preload_libraries` before starting the cluster, and follow the instructions for turning off WAL encryption above before uninstalling the shared library.
