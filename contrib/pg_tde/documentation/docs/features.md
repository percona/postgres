# Features

`pg_tde` is available in two variants (or "flavors"):

* PostgreSQL Community
* [Percona Server for PostgreSQL](https://docs.percona.com/postgresql/17/)
The key difference between these variants lies in the set of supported features, which depends on the underlying Storage Manager API. The PostgreSQL Community variant uses the default Storage Manager API, while the Percona Server for PostgreSQL provides an extended Storage Manager API that allows integration with custom storage managers.

The following table presents the features available for each variant:

| Percona Server for PostgreSQL version | PostgreSQL Community version (deprecated)  |
|-------------------------------|----------------------|
| Table encryption: <br> - data tables, <br> - **Index data for encrypted tables**, <br> - TOAST tables, <br> - temporary tables created during the database operation.<br><br> Metadata of those tables is not encrypted.  | Table encryption: <br> - data tables, <br> - TOAST tables <br> - temporary tables created during the database operation.<br><br> Metadata of those tables is not encrypted. |
| **Global** Write-Ahead Log (WAL) encryption: for data in encrypted and non-encrypted tables | Write-Ahead Log (WAL) encryption of data in encrypted tables |
| Single-tenancy support via global keyring provider |   | 
| Multi-tenancy support | Multi-tenancy support |
| Table-level granularity | Table-level granularity |
| Key management via: <br> - HashiCorp Vault; <br> - KMIP server; <br> - Local keyfile | Key management via: <br> - HashiCorp Vault; <br> - Local keyfile |
| Logical replication of encrypted tables | |

[Get started](install.md){.md-button}