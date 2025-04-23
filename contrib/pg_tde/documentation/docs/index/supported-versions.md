# Versions and supported PostgreSQL deployments

The `pg_tde` extension comes in two distinct versions with specific access methods to encrypt the data. These versions are database-specific and differ in terms of what they encrypt and with what access method. Each version is characterized by the database it supports, the access method it provides, and the scope of encryption it offers.

* **Version for Percona Server for PostgreSQL**

    This `pg_tde` version is based on and supported for [Percona Server for PostgreSQL 17.x :octicons-link-external-16:](https://docs.percona.com/postgresql/17/postgresql-server.html) - an open source binary drop-in replacement for PostgreSQL Community. It provides the `tde_heap` access method and offers [full encryption capabilities](features.md).

* **Community version** (deprecated)

    This version is available with PostgreSQL Community 16 and 17, and Percona Distribution for PostgreSQL 16. It provides the `tde_heap_basic` access method, offering limited encryption features. The limitations are in encrypting WAL data only for tables created using the extension and no support of index encryption nor logical replication.

## Which version to choose?

Enjoy full encryption with the Percona Server for PostgreSQL version and the `tde_heap` access method. The Community version is deprecated and is planned to be removed in future releases.

Still not sure? [Contact our experts](https://www.percona.com/about/contact) to find the best solution for you.
