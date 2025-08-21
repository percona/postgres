# pg_tde 2.0 ({{date.GA20}})

The `pg_tde` by Percona extension brings [Transparent Data Encryption (TDE)](../index/about-tde.md) to PostgreSQL and enables you to keep sensitive data safe and secure.

[Get Started](../install.md){.md-button}

## Release Highlights

### WAL encryption is now generally available

The WAL (Write-Ahead Logging) encryption feature is now fully supported and production-ready, it adds secure logging to `pg_tde`, expanding Percona's PostgreSQL encryption coverage by enabling secure, transparent encryption of write-ahead logs using the same key infrastructure as data encryption.

### WAL encryption upgrade limitation

Clusters that used WAL encryption in the beta release (`pg_tde` 1.0 or older) cannot be upgraded to `pg_tde` 2.0. The following error indicates that WAL encryption was enabled:

```sql
FATAL: principal key not configured
HINT: Use pg_tde_set_server_key_using_global_key_provider() to configure one.
```

Clusters that did not use WAL encryption in beta can be upgraded normally.

### Documentation updates

* Updated the [Limitations](../index/tde-limitations.md) topic to include WAL encryption limitations and supported tools.

## Known issues

* The default `mlock` limit on Rocky Linux 8 for ARM64-based architectures equals the memory page size and is 64 Kb. This results in the child process with `pg_tde` failing to allocate another memory page because the max memory limit is reached by the parent process.

To prevent this, you can change the `mlock` limit to be at least twice bigger than the memory page size:

* temporarily for the current session using the `ulimit -l <value>` command.
* set a new hard limit in the `/etc/security/limits.conf` file. To do so, you require the superuser privileges.

Adjust the limits with caution since it affects other processes running in your system.

## Changelog

### New Features

- [PG-1497](https://perconadev.atlassian.net/browse/PG-1497) WAL encryption is now generally available (GA)
- [PG-1037](https://perconadev.atlassian.net/browse/PG-1037) Make `pg_rewind` work with encrypted WAL

### Improvements

### Bugs Fixed

- [PG-1391](https://perconadev.atlassian.net/browse/PG-1391) Prevent WAL key mismatches on replicas after `pg_basebackup`
- [PG-1452](https://perconadev.atlassian.net/browse/PG-1452) `pg_tde_change_key_provider` did not work without `-D` flag even if `PGDATA` was set
