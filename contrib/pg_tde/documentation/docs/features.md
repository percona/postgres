# Features

`pg_tde` is available for [Percona Server for PostgreSQL](https://docs.percona.com/postgresql/17/)
The Percona Server for PostgreSQL provides an extended Storage Manager API that allows integration with custom storage managers.

The following features are available for the extension:

* Table encryption, including:
    * Data tables
    * Index data for encrypted tables
    * TOAST tables
    * Temporary tables created during database operations
AÅ: Created how?

!!! note
    Metadata of those tables is not encrypted.

* Global Write-Ahead Log (WAL) encryption for data in both encrypted and non-encrypted tables
AÅ: WAL encryption should not be mentioned as a feature since we don't yet have it in more than a beta preview.
* Single-tenancy support via a global keyring provider
* Multi-tenancy support
* Table-level granularity for encryption and access control
* Multiple Key management options
* Logical replication of encrypted tables
AÅ: We do not do anything for logical replication, do we?

[Overview](index/index.md){.md-button} [Get Started](install.md){.md-button}
