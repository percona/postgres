# Streaming Replication with tde_heap

This section outlines how to set up PostgreSQL streaming replication when the `pg_tde` extension (specifically the `tde_heap` access method) is enabled on the primary server.

The following steps assume:

* You have configured a global key provider for both **primary** and **standby** (see [Configure Key Management (KMS)](global-key-provider-configuration/index.md)).
* You have enabled `pg_tde` and you have setup at least one active key on the **primary**.
* Both primary and standby run the **same** Percona PostgreSQL version.

## 1. Configure the Primary

### Configure postgresql.conf

* Ensure you set the following replication settings in `postgresql.conf`:

    ```ini
    # Example of WAL and replication settings
    wal_level            = replica
    max_wal_senders      = 5
    max_replication_slots = 1
    wal_keep_size        = '1GB'
    # Enable TDE in WAL pipeline
    shared_preload_libraries = 'pg_tde' # Loads TDE hooks at server start.
    ```

    !!! note
        Make sure you set `max_replication_slots` before creating any slot.

* (Optional - **To review**) Create a physical slot to retain the encrypted WAL, set `max_replication_slots ≥ 1` and then:

    ```sql
    SELECT pg_create_physical_replication_slot('tde_slot');
    ```

* Ensure you have [configured the global key provider](global-key-provider-configuration/index.md).
* Create the [principal key](functions#pg_tde_set_server_key_using_global_key_provider).
* Enable [WAL encryption](wal-encryption). **Restart** PostgreSQL.
* Ensure the extension is installed in each database:

    ```sql
    CREATE EXTENSION IF NOT EXISTS pg_tde;
    ```

* (Optional) If you want to block any unencrypted tables, you can [enforce table-level encryption](variables#pg_tde.enforce_encryption):

    ```ini
    pg_tde.enforce_encryption = on
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
-v -P
```

!!! note
    Run pg_basebackup only **after** slot creation if using `--slot=tde_slot`.

### Initial standby setup

* Ensure that in `postgresql.conf` or `postgresql.auto.conf`:

```ini
shared_preload_libraries = 'pg_tde'
hot_standby = on
```

!!! note
    By default `pg_tde.inherit_global_providers = on`, so the standby inherits your global KMS configuration automatically.

* Install the extension so the standby can register `tde_heap`:

```sql
CREATE EXTENSION IF NOT EXISTS pg_tde;
```

* For PostgreSQL ≥13, in `postgresql.auto.conf`, ensure you have set the following:

```ini
primary_conninfo = 'host=primary_ip port=5432 \
                    user=example_replicator password=example_password \
                    application_name=standby_node sslmode=verify-full \
                    sslrootcert=/path/to/ca.pem'
primary_slot_name = 'tde_slot'
```

### On the standby host, after pg_basebackup and configuration is set:

```bash
touch $PGDATA/standby.signal
```

PostgreSQL looks for the `standby.signal` (replacing `recovery.conf` as of v12) to know it should enter streaming recovery.

!!! note
    Ensure the standby has access to the **same** encryption key material or provider configuration used by the primary.

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
