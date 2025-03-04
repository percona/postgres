# pg_tde Release Candidate {{date.RC}}

`pg_tde` extension brings in [Transparent Data Encryption (TDE)](tde.md) to PostgreSQL and enables you to keep sensitive data safe and secure.

[Get started](../install.md){.md-button}


!!! important

    This version of Percona Transparent Data Encryption extension **is 
    not recommended for production environments yet**. We encourage you to test it and [give your feedback](https://forums.percona.com/c/postgresql/pg-tde-transparent-data-encryption-tde/82).
  
    This will help us improve the product and make it production-ready faster.

## Release Highlights

This release provides the following features and improvements:

* **Improved performance with reworked WAL encryption mechanism**. 

   The approach to WAL encryption has changed. Now, `pg_tde` encrypts entire WAL files starting from the first WAL write after the server was started with the encryption turned on. The information about what is encrypted is stored in the internal key metadata. This change improves WAL encryption flow with native replication and increases performance for large scale databases. 

* **Default encryption key for single-tenancy**. 

   The new functionality allows you to set a default principal key for the entire database cluster. This key is used to encrypt all databases and tables that do not have a custom principal key set. This feature simplifies encryption configuration and management in single-tenant environments where each user has their own database instance.

* **Ability to change key provider configuration**

   You no longer need to configure a new key provider and set a new principal key if the provider's configuration changed. Now can change the key provider configuration both for the current database and the entire PostgreSQL cluster using [functions](../functions.md#key-provider-management). This enhancement lifts existing limitations and is a native and common way to operate in PostgreSQL.

* **Key management permissions**

   The new functions allow you to manage permissions for global and database key management separately. This feature provides more granular control over key management operations and allows you to delegate key management tasks to different roles.

* **Additional information about principal keys and providers**

   The new functions allow you to display additional information about principal keys and providers. This feature helps you to understand the current key configuration and troubleshoot issues related to key management.

* The `tde_heap_basic` access method is deprecated and will be removed in future releases. Use the `tde_heap` access method instead.



## Changelog

### New Features
 
* [PG-1002](https://perconadev.atlassian.net/browse/PG-1002) - Added the requirement of an explicit configuration of a WAL principal key to ensure correct WAL encryption

* [PG-1234](https://perconadev.atlassian.net/browse/PG-1234) - Added functions for separate global and database key management permissions 

* [PG-1255](https://perconadev.atlassian.net/browse/PG-1255) - Added functionality to delete key providers

* [PG-1256](https://perconadev.atlassian.net/browse/PG-1256) - Added single-tenant support via the default principal key functionality

* [PG-1258](https://perconadev.atlassian.net/browse/PG-1258) - Added functions to display additional information  about principal keys / providers 

* [PG-1294](https://perconadev.atlassian.net/browse/PG-1294) - Improve WAL encryption by encrypting entire WAL files

* [PG-1303](https://perconadev.atlassian.net/browse/PG-1303) - Deprecated tde_heap_basic access method

## Improvements

* [PG-1361](https://perconadev.atlassian.net/browse/PG-1361) - Investigated and fixed pg_tde relocatability

* [PG-1367](https://perconadev.atlassian.net/browse/PG-1367) - Created a separate generic script that is used to configure server with pg_tde from the existing make-test-tde.sh script

### Bugs Fixed


* [PG-821](https://perconadev.atlassian.net/browse/PG-821) - Fixed the issue with `pg_basebackup` failing when configuring replication

* [PG-847](https://perconadev.atlassian.net/browse/PG-847) - Fixed the issue with `pg_basebackup` and `pg_checksum` throwing an error on files created by `pg_tde` when the checksum is enabled on the database cluster

* [PG-1004](https://perconadev.atlassian.net/browse/PG-1004) Fixed the issue with `pg_checksums` utility failing during checksum verification on `pg_tde` tables. Now `pg_checksum` skips encrypted relations by looking if the relation has a custom storage manager (SMGR) key.

* [PG-1373](https://perconadev.atlassian.net/browse/PG-1373) Fixed the issue with potential unterminated strings by using the `memset()` or `palloc0()` instead of the `strncpy()` function.   

* [PG-1376](https://perconadev.atlassian.net/browse/PG-1376) - Fixed the issue with getting a warning message when setting a default principal key by using the correct lock type during the function execution.

* [PG-1378](https://perconadev.atlassian.net/browse/PG-1378) - Fixed the issue with toast tables created by ALTER TABLE command not being encrypted by fixing the sequence and alter table handling by event trigger 

* [PG-1380](https://perconadev.atlassian.net/browse/PG-1380) Added support for `pg_tde_is_encrypted()` function on indexes and sequences

* [PG-1222](https://perconadev.atlassian.net/browse/PG-1222) - Fixed the bug with  confused relations with the same `RelFileNumber` in different databases