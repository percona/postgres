# What does TDE encrypt?

`pg_tde` encrypts the following:

* User data in tables, including TOAST tables, that are created using the extension. The metadata of those tables is not encrypted.
* Temporary tables created during the database operation for data tables created using the extension
* Write-Ahead Log (WAL) data for the entire database cluster. This includes WAL data in encrypted and non-encrypted tables
* Indexes on encrypted tables
* Logical replication on encrypted tables

[Check the full feature list](../features.md){.md-button}
