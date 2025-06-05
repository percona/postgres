# Streaming Replication with tde_heap

This section outlines how to set up PostgreSQL streaming replication when the `pg_tde` extension (specifically the `tde_heap` access method) is enabled on the primary server.

The following steps assume:

* You have enabled `pg_tde` and you have setup at least one active key on the **primary**.
* You have configured a global key provider for the **primary**, see [Configure Key Management (KMS)](global-key-provider-configuration/index.md) for more information.
* Ensure the certificate files are accessible for the standby, and that `pg_tde` is added to the shared preload libraries.

## 1. Configure the Primary

### Configure postgresql.conf

* Ensure you have configured `postgresql.conf`.
* Ensure you have configured the provider.
* Create the [principal key](functions#pg_tde_set_server_key_using_global_key_provider).
* Ensure the extension is installed where it is needed:

    ```sql
    CREATE EXTENSION IF NOT EXISTS pg_tde;
    ```

### Create the replication role

Ensure your primary has a replication role:

```sql
CREATE ROLE example_replicator WITH REPLICATION LOGIN PASSWORD 'example_password';
```

### Configure pg_hba.conf

To connect to the replication server, add the following line in `pg_hba.conf`:

```conf
host  replication  example_replicator  standby_ip/32  scram-sha-256
```

Ensure that it is placed before the other host rules for replication and then **reload** the configuration:

```sql
SELECT pg_reload_conf();
```

## 2. Configure the Standby

### Perform an encrypted database backup

Run the base backup from your standby machine to pull the encrypted base backup:

```bash
export PGPASSWORD='example_password'
pg_basebackup \
  -h primary_ip \
  -D /var/lib/pgsql/data \
  -U example_replicator \
  --wal-method=stream \
  --slot=tde_slot \
  -C \
  -c fast \
  -v -P
```

### Initial standby setup

* Ensure that in `postgresql.conf` or `postgresql.auto.conf`:

```ini
shared_preload_libraries = 'pg_tde'
hot_standby = on
```

## 3. Start and validate replication

```bash
sudo systemctl start postgresql
```

* On primary:

```sql
SELECT client_addr, state 
FROM pg_stat_replication;
```

* On standby:

```sql
SELECT
    pg_is_in_recovery()          AS in_recovery,
    pg_last_wal_receive_lsn()    AS receive_lsn,
    pg_last_wal_replay_lsn()     AS replay_lsn;
```
