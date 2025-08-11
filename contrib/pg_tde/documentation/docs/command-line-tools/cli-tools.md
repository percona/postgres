# Overview of pg_tde CLI tools

The `pg_tde` extension introduces new command-line utilities and extends some existing PostgreSQL tools to support encrypted WAL and tables.

## New tools

* [pg_tde_change_key_provider](./pg-tde-change-key-provider.md): change encryption key provider for a database
* [pg_tde_archive_decrypt](./pg-tde-archive-decrypt.md): custom archive command for archiving plaintext WAL
* [pg_tde_restore_encrypt](./pg-tde-restore-encrypt.md): custome restore command for making sure restored WAL is encrypted

## Extended tools

* [pg_checksums](./pg-tde-checksums.md): verify data checksums (non-encrypted files only)
* [pg_waldump](./pg-waldump.md): inspect and decrypt WAL files
