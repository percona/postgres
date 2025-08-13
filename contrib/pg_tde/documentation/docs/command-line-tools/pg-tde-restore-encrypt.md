# pg_tde_restore_encrypt

The `pg_tde_restore_encrypt` tool wraps a normal restore command from the WAL archive and writes them to disk in a format compatible with `pg_tde`.

!!! note

    This command is often use together with [pg_tde_archive_decrypt](./pg-tde-archive-decrypt.md).

## How it works

1. Calls the configured restore command
2. The restore command writes the WAL file from the archive to a temporary RAM disk file (`/dev/shm`)
3. Copies that file to the PostgreSQL data directory

## Usage

```bash
pg_tde_restore_encrypt [OPTION]
pg_tde_restore_encrypt SOURCE-NAME DEST-PATH RESTORE-COMMAND
```

## Parameter descriptions

* `SOURCE-NAME`: name of the WAL file to retrieve from the archive
* `DEST-PATH`: path where the encrypted WAL file should be written
* `RESTORE-COMMAND`: restore command to wrap; `%p` and `%f` are replaced with the WAL file name and path to write the unencrypted WAL, respectively

## Options

* `-V, --version`: show version information, then exit
* `-?, --help`: show help information, then exit

!!! note

    Any `%f` or `%p` parameter in `RESTORE-COMMAND` has to be escaped as `%%f` or `%%p` respectively if used as `restore_command` in `postgresql.conf`.

## Examples

### Using `cp`

```ini
restore_command='pg_tde_restore_encrypt %f %p "cp /mnt/server/archivedir/%%f %%p"'
```

### Using `PgBackRest`

```ini
restore_command='pg_tde_restore_encrypt %f %p "pgbackrest --stanza=your_stanza archive-get %%f \"%%p\""'
```
