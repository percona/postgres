# Streaming Replication with tde_heap

This section outlines how to set up PostgreSQL streaming replication when the `pg_tde` extension (specifically the [`tde_heap`](index/table-access-method.md) access method) is enabled on the primary server.

Before you begin, ensure you have followed the [`pg_tde` setup instructions](setup.md), which includes:

- Installing the `pg_tde` extension binaries, where they are needed, on **both** the primary and standby servers.
- Configuring `shared_preload_libraries = 'pg_tde'` in `postgresql.conf` on **both** systems.
- Initializing the extension and setting a principal key on the **primary**.

!!! note
    You do **not** need to run `CREATE EXTENSION` on the standby. It will be replicated automatically.

## 1. Configure the Primary

### Create a principal key

Use the [`pg_tde_set_server_key_using_global_key_provider`](functions.md#pg_tde_set_server_key_using_global_key_provider) function to create a principal key.

### Create the replication role

Create a replication role on the primary:

```sql
CREATE ROLE example_replicator WITH REPLICATION LOGIN PASSWORD 'example_password';
```

### Configure pg_hba.conf

To allow the replica to connect to the primary server, add the following line in `pg_hba.conf`:

```conf
host  replication  example_replicator  standby_ip/32  scram-sha-256
```

Ensure that it is placed before the other host rules for replication and then **reload** the configuration:

```sql
SELECT pg_reload_conf();
```

## 2. Configure the Standby

### Perform a database backup

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

## 3. Start and validate replication

Start the PostgreSQL service:

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

!!! tip
    Want to verify if everything works? Run `SELECT pg_tde_is_encrypted('your_encrypted_table');` on the standby to confirm that the encryption is active and the keys are resolved.
