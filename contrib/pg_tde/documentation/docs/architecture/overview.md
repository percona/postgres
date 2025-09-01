# Architecture overview

`pg_tde` is a **customizable, complete, data at rest encryption extension** for PostgreSQL.

The following sections break down the key architectural components of this design.

**Customizable** means that `pg_tde` aims to support many different use cases:

* Encrypting either every table in every database or only some tables in some databases
* Encryption keys can be stored on various external key storage servers including HashiCorp Vault and KMIP servers.
* Using one key for everything or different keys for different databases
* Storing every key on the same key storage, or using different storages for different databases
* Handling permissions: who can manage database specific or global permissions, who can create encrypted or not encrypted tables

**Complete** means that `pg_tde` aims to encrypt data at rest.

**Data at rest** means everything written to the disk. This includes the following:

* Table data files
* Indexes
* Sequences
* Temporary tables
* Write Ahead Log (WAL), still in beta. **Do not enable this feature in production environments**.

**Extension** means that `pg_tde` should be implemented only as an extension, possibly compatible with any PostgreSQL distribution, including the open source community version. This requires changes in the PostgreSQL core to make it more extensible. Therefore, `pg_tde` currently works only with the [Percona Server for PostgreSQL](https://docs.percona.com/postgresql/17/index.html) - a binary replacement of community PostgreSQL and included in Percona Distribution for PostgreSQL.

## Main components

The main components of `pg_tde` are the following:

* **Core server changes** focus on making the server more extensible, allowing the main logic of `pg_tde` to remain separate, as an extension. Core changes also add encryption-awareness to some command line tools that have to work directly with encrypted tables or encrypted WAL files.

    [Percona Server for PostgreSQL location](https://github.com/percona/postgres/tree/{{tdebranch}})

* The **`pg_tde` extension itself** implements the encryption code by hooking into the extension points introduced in the core changes, and the already existing extension points in the PostgreSQL server.

    Everything is controllable with GUC variables and SQL statements, similar to other extensions.

* The **keyring API / libraries** implement the key storage logic with different key providers. The API is internal only, the keyring libraries are part of the main library for simplicity.
In the future these could be extracted into separate shared libraries with an open API, allowing the use of third-party providers.
