# Impact of pg_tde on database operations

This page summarizes how `pg_tde` interacts with core PostgreSQL operations.

| Area | Affected | Notes / Actions |
|------|-----------|-----------------|
| **Backups** | ✅ Yes | Encrypted backups require `pg_tde`-aware tools. See [Backup with WAL encryption](../how-to/backup-wal-enabled.md). |
| **Restore** | ✅ Yes | Restored data remains encrypted; `pg_tde` transparently handles decryption. See [Restore encrypted backups](../how-to/restore-backups.md). |
| **Streaming replication** | ⚠️ Partial | Replication requires `pg_tde` on replicas. If keys are local, they must be manually copied; shared KMS works automatically. |
| **Logical replication** | ❌ No | Logical replication operates on plaintext data; unaffected. |
| **Monitoring and statistics** | ❌ No | `pg_stat_monitor` views and metrics are unchanged. |
| **Extensions** | ⚠️ Maybe | Extensions that read raw data files may need adjustment. |
| **Performance** | ⚠️ Slight | Minor CPU overhead due to encryption. |
| **Configuration management** | ✅ Yes | `pg_tde.conf` parameters affect key handling and WAL encryption. |
