# pg_tde_archive_decrypt

Helper command to archive WAL segments in uncrypted form. This is necessary since the WAL encryption keys in the two-key hierarchy (see [Architecture](../architecture/architcture.md)) are specific to the host which generated them and may not be available at the machine which will replay the WAL.

The command wraps your normal archive command and creates a temporary file on a RAM disk, `/dev/shm`, which is then fed as input to your archive command.

This command is often use in conjunction with [pg_tde_restore_encrypt](./pg-tde-restore-encrypt.md).

To use this safely make sure to encrypt the files stored in your WAL archive which is supported by e.g. PgBackRest.

## Examples

Simple example using `cp`:

```ini
archive_command = '/lib/postgresql/17/bin/pg_tde_archive_decrypt %p cp %p /archive/%f'
```

With PgBackRest:

```ini
archive_command = '/lib/postgresql/17/bin/pg_tde_archive_decrypt %p pgbackrest --stanza=tde archive-push %p'
```
