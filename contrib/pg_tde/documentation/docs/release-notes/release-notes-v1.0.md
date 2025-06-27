# pg_tde 1.0 ({{date.GA10}})

The `pg_tde` by Percona extension brings in [Transparent Data Encryption (TDE)](../index/index.md) to PostgreSQL and enables you to keep sensitive data safe and secure.

[Get Started](../install.md){.md-button}

## Release Highlights

* **Streaming and logical replication compatibility**

You can now use `pg_tde` in replication setups.

* **Improved performance testing & automation**

Bare-metal fuzz testing, performance benchmarking with CI/CD pipelines, and daily reporting integrations with Grafana and InfluxDB help ensure robustness and transparency.

* **Key management enhancements**

Added SQL-level functions and CLI tools for rotating, validating, and managing encryption keys. Now more compliant with PostgreSQL standards.

* **Better developer experience**

Contributor guides, PostgreSQL-style CLI, static analysis integration (Clang), and extensive refactoring improve maintainability and onboarding for new contributors.

* **Security hardened**

Sensitive metadata redaction, improved error messages, proper SQLSTATE codes, and stricter key validation increase security and clarity.

* **Major documentation updates**

The `pg_tde` documentation has received significant updates, which include:

- New configuration guides for Fortanix, Vault, KMIP and OpenBAO
- Reorganized and expanded topics for Architecture, GUC, Functions, TDE Operations and FAQ
- Extensive and numerous refinements and clarifications across the entire site

Explore the full documentation [in the official `pg_tde` documentations](https://docs.percona.com/pg-tde/index.html).

## Upgrade considerations

`pg_tde` {{tdeversion}} is **not** backward compatible with previous `pg_tde` versions, like Release Candidate 2, due to significant changes in code. This means you **cannot** directly upgrade from one version to another. You must do **a clean installation** of `pg_tde`.

## Known issues

* The default `mlock` limit on Rocky Linux 8 for ARM64-based architectures equals the memory page size and is 64 Kb. This results in the child process with `pg_tde` failing to allocate another memory page because the max memory limit is reached by the parent process.

To prevent this, you can change the `mlock` limit to be at least twice bigger than the memory page size:

* temporarily for the current session using the `ulimit -l <value>` command.
* set a new hard limit in the `/etc/security/limits.conf` file. To do so, you require the superuser privileges.

Adjust the limits with caution since it affects other processes running in your system.

## Changelog

### New Features

- [PG-802](https://perconadev.atlassian.net/browse/PG-802) – Documented setting up streaming replication with `pg_tde`
- [PG-829](https://perconadev.atlassian.net/browse/PG-829) – Refactored and simplified key map code  
- [PG-836](https://perconadev.atlassian.net/browse/PG-836) – Added custom wait events to writing to key files and key provider files  
- [PG-1257](https://perconadev.atlassian.net/browse/PG-1257) – Added SQL function to remove the current principal key  
- [PG-1292](https://perconadev.atlassian.net/browse/PG-1292) – Added a CI/CD performance test job in PSP GH repo
- [PG-1316](https://perconadev.atlassian.net/browse/PG-1316) – Integrated daily automated Performance Results with InfluxDB and Grafana  
- [PG-1351](https://perconadev.atlassian.net/browse/PG-1351) – Documented how to decrypt old backups after the principal key was rotated
- [PG-1443](https://perconadev.atlassian.net/browse/PG-1443) – Made `pg_tde_change_key_provider` CLI utility follow PostgreSQL coding style  
- [PG-1448](https://perconadev.atlassian.net/browse/PG-1448) – `pg_tde` now uses jsonc instead of the internal json API
- [PG-1464](https://perconadev.atlassian.net/browse/PG-1464) – Integrated the clang static analyzer for `pg_tde`

### Improvements

- [PG-953](https://perconadev.atlassian.net/browse/PG-953) – The tdemap code now allows the creation of duplicate keys
- [PG-1435](https://perconadev.atlassian.net/browse/PG-1435) – Improved error message explanations  
- [PG-1499](https://perconadev.atlassian.net/browse/PG-1499) – Enhanced encryption metadata visibility in `pg_tde`
- [PG-1527](https://perconadev.atlassian.net/browse/PG-1527) – Added proper error codes for error messages in `pg_tde`
- [PG-1617](https://perconadev.atlassian.net/browse/PG-1617) – Removed relation key cache
- [PG-1635](https://perconadev.atlassian.net/browse/PG-1635) – User-facing TDE functions now return void

### Bugs Fixed

- [PG-1581](https://perconadev.atlassian.net/browse/PG-1581) – Fixed PostgreSQL crashes on table access when KMIP key is unavailable after restart  
- [PG-1583](https://perconadev.atlassian.net/browse/PG-1583) – Fixed a crash when dropping the `pg_tde` extension with CASCADE after changing the key provider file  
- [PG-1585](https://perconadev.atlassian.net/browse/PG-1585) – Fixed the vault provider re-addition that failed after server restart with a new token  
- [PG-1592](https://perconadev.atlassian.net/browse/PG-1592) – Improve error logs when Server Key Info is requested without being created  
- [PG-1593](https://perconadev.atlassian.net/browse/PG-1593) – Fixed runtime failures when invalid Vault tokens are allowed during key provider creation
- [PG-1600](https://perconadev.atlassian.net/browse/PG-1600) – Fixed Postmaster error when dropping a table with an unavailable key provider  
- [PG-1605](https://perconadev.atlassian.net/browse/PG-1605) – Fixed the creation of undeclared dependencies for `pg_tde_grant_database_key_management_to_role()`
- [PG-1606](https://perconadev.atlassian.net/browse/PG-1606) – Fixed missing superuser check in role grant function leads to misleading errors  
- [PG-1607](https://perconadev.atlassian.net/browse/PG-1607) – Made CA parameter optional when Vault server runs without SSL  
- [PG-1608](https://perconadev.atlassian.net/browse/PG-1608) – Updated and fixed global key configuration parameters in documentation  
- [PG-1613](https://perconadev.atlassian.net/browse/PG-1613) – Fixed the `pg_tde_change_key_provider` CLI tool
- [PG-1637](https://perconadev.atlassian.net/browse/PG-1637) – Fixed unused keys in key files which caused issues after OID wraparound  
- [PG-1651](https://perconadev.atlassian.net/browse/PG-1651) – Fixed the CLI tool when working with Vault key export/import  
- [PG-1652](https://perconadev.atlassian.net/browse/PG-1652) – Fixed when the server fails to find encryption keys after CLI-based provider change  
- [PG-1662](https://perconadev.atlassian.net/browse/PG-1662) – Fixed the creation of inconsistent encryption status when altering partitioned tables
- [PG-1663](https://perconadev.atlassian.net/browse/PG-1663) – Fixed the indexes on partitioned tables which were not encrypted
- [PG-1700](https://perconadev.atlassian.net/browse/PG-1700) – Fixed the error hint when the principal key is missing
