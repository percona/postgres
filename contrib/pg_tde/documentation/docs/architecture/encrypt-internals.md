# Encryption architecture

## Two-key hierarchy

`pg_tde` uses two kinds of keys for encryption:

* Internal keys to encrypt the data. They are stored in PostgreSQL's data directory under `$PGDATA/pg_tde`.
* Higher-level keys to encrypt internal keys. These keys are called *principal keys*. They are stored externally, in a Key Management System (KMS) using the key provider API.

`pg_tde` uses one principal key per database. Every internal key for the given database is encrypted using this principal key.

Internal keys are used for specific database files: each file with a different [Object Identifier (OID) :octicons-link-external-16:](https://www.postgresql.org/docs/current/datatype-oid.html) has a different internal key.

This means that, for example, a table with 4 indexes will have at least 5 internal keys - one for the table, and one for each index.

If a table has additional associated relations, such as sequences or a TOAST table, those relations will also have separate keys.

## Encryption algorithm

`pg_tde` currently uses the following encryption algorithms:

* `AES-128-CBC` for encrypting database files; encrypted with internal keys.
* `AES-128-CTR` for WAL encryption; encrypted with internal keys.
* `AES-128-GCM` for encrypting internal keys; encrypted with the principal key.

Support for other cipher lengths / algorithms is planned in the future.

## Encryption workflow

`pg_tde` makes it possible to encrypt everything or only some tables in some databases.

To support this without metadata changes, encrypted tables are labeled with a `tde_heap` access method marker.

The `tde_heap` access method is the same as the `heap` one. It uses the same functions internally without any changes, but with the different name and ID. In such a way `pg_tde` knows that `tde_heap` tables are encrypted and `heap` tables are not.

The initial decision what to encrypt is made using the `postgres` event trigger mechanism: if a `CREATE TABLE` or `ALTER TABLE` statement uses the `tde_heap` clause, the newly created data files are marked as encrypted. Then file operations encrypt or decrypt the data.

Later decisions are made using a slightly modified Storage Manager (SMGR) API: when a database file is re-created with a different ID as a result of a `TRUNCATE` or a `VACUUM FULL` command, the newly created file inherits the encryption information and is either encrypted or not.

## WAL encryption

WAL encryption is controlled globally via a global GUC variable, `pg_tde.wal_encrypt`, that requires a server restart.

WAL keys also contain the [LSN](https://www.postgresql.org/docs/17/wal-internals.html) of the first WAL write after key creation. This allows `pg_tde` to know which WAL ranges are encrypted or not and with which key.

The setting only controls writes so that only WAL writes are encrypted when WAL encryption is enabled. This means that WAL files can contain both encrypted and unencrypted data, depending on what the status of this variable was when writing the data.

`pg_tde` keeps track of the encryption status of WAL records using internal keys. When the server is restarted it writes a new internal key if WAL encryption is enabled, or if it is disabled and was previously enabled it writes a dummy key signaling that WAL encryption ended.

With this information the WAL reader code can decide if a specific WAL record has to be decrypted or not and which key it should use to decrypt it.

## Encrypting other access methods

Currently `pg_tde` only encrypts `heap` tables and other files such as indexes, TOAST tables, sequences that are related to the `heap` tables.

Indexes include any kind of index that goes through the SMGR API, not just the built-in indexes in PostgreSQL.

In theory, it is also possible to encrypt any other table access method that goes through the SMGR API by similarly providing a marker access method to it and extending the event triggers.

## Storage Manager (SMGR) API

`pg_tde` relies on a slightly modified version of the SMGR API. These modifications include:

* Making the API generally extensible, where extensions can inject custom code into the storage manager
* Adding tracking information for files. When a new file is created for an existing relation, references to the existing file are also passed to the SMGR functions

With these modifications, the `pg_tde` extension can implement an additional layer on top of the normal Magnetic Disk SMGR API: if the related table is encrypted, `pg_tde` encrypts a file before writing it to the disk and, similarly, decrypts it after reading when needed.
