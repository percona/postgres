# pg_tde_restore_encrypt

Helper command to take unecrypted segments from the WAL archive and write them to disk in a format which `pg_tde` understands.

The command wraps your normal restore command and has it write the file from the archive to a temporary file on a RAM disk, `/dev/shm` before copying it into PostgreSQL's data directory.

This command is often use in conjunction with [pg_tde_archive_decrypt](./pg-tde-archive-decrypt.md).

## Examples

Simple example using `cp`:

```ini
restore_command = '/lib/postgresql/17/bin/pg_tde_restore_enrypt %f %p cp /archive/%f %p'
```

With PgBackRest add something like the following to `/etc/pgbackrest.conf` or to the command line:

```ini
recovery-option=restore_command=/lib/postgresql/17/bin/pg_tde_restore_encrypt %f %p pgbackrest --stanza=demo archive-get %f "%p"
```
