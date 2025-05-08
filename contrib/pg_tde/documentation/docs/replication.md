# Streaming Replication with tde_heap

This topic outlines how to set up PostgreSQL streaming replication when `pg_tde` (specifically the `tde_heap` access method) is enabled on the primary server.

!!! note
    Physical streaming replication copies data blocks directly from the primary to the standby. If these blocks are encrypted on the primary, they will arrive encrypted on the standby. Therefore, the standby **must** have access to the **exact same encryption keys** as the primary to decrypt and read this data.

## 1. Key Concepts

* **`tde_heap`:** An access method that encrypts entire tables using a master key. It's simpler to manage in a replication scenario than `tde_heap_basic`.
* **Master Key:** The central key used by `pg_tde` to encrypt/decrypt data encryption keys (DEKs) or, in simpler configurations, directly encrypt data.
* **Key Provider:** The mechanism `pg_tde` uses to fetch the master key (a local file, HashiCorp Vault, and more).
* **Physical Streaming Replication:** Replicates WAL records, which contain block-level changes. Encrypted data blocks are replicated as-is.

## 2. How to Set Up Key Provider and Master Key for Replication

The standby server(s) **must** be configured to use the **same key provider** and access the **same master key** as the primary server.

### Scenario 1: File-based Key Provider (Example)

If you're using a `keyring_file`:

1. **Primary:**
    * Configure `pg_tde.key_provider_type = 'file'` (or your chosen file provider type).
    * Configure `pg_tde.keyring_file_path = '/path/to/your/master.key'` (or equivalent for your provider).
    * Ensure the master key file exists and has appropriate permissions (readable by the PostgreSQL OS user).
    * Initialize the master key if it's the first time: `SELECT pg_tde_master_key_init();`
2. **Standby:**
    * Before starting the standby, **securely copy** the *exact same master key file* from the primary to the *exact same path* on the standby (`/path/to/your/master.key`).
    * Ensure permissions on the standby's copy are identical (readable by PostgreSQL OS user).
    * In the standby's `postgresql.conf`, configure `pg_tde.key_provider_type` and `pg_tde.keyring_file_path` to be **identical** to the primary's configuration.

### Scenario 2: Centralized Key Provider

1. **Primary:**
    * Configure `pg_tde.key_provider_type = 'vault'` (or your chosen Vault provider type).
    * Configure Vault connection parameters (address, token/auth method, key path in Vault, etc.).
    * Ensure the master key exists in Vault at the specified path.
    * Initialize if needed: `SELECT pg_tde_master_key_init('your_master_key_name_in_vault');`
2. **Standby:**
    * In the standby's `postgresql.conf`, configure `pg_tde.key_provider_type` and all Vault connection parameters to be **identical** to the primary's configuration.
    * Ensure the standby server has network access to the Vault server and the necessary credentials/permissions to read the *same master key* from Vault.
    * When the standby starts, it will use these settings to fetch the master key from Vault.

**Is it possible to use the same key provider and master key?**

**Yes, it is mandatory.** For physical replication to function with `pg_tde`, the standby *must* use the same master key as the primary to decrypt the replicated data blocks. This implies using a key provider setup that allows the standby to access this same key.

## 3. Encrypted Table Replication

**If a table on the primary site is encrypted, will all the standby sites also have the encrypted table replicated, given that the same key is implemented on the standby sites as well?**

Yes.
Physical replication works at the block level.

1. When you encrypt a table on the primary using `pg_tde`, the data blocks on disk are encrypted.
2. When data in this table is modified, the changes (which are also encrypted) are written to WAL.
3. Streaming replication sends these WAL records (containing encrypted block changes) to the standby.
4. The standby applies these WAL records, writing the encrypted blocks to its own disk.
5. If the standby has the same master key available via its configured key provider, it can then decrypt these blocks when you query the table on the standby.

If the standby *does not* have the correct key, it still replicates the encrypted data, but it is unable to read it, and queries against encrypted tables fail.

## 4. Setup Steps

This assumes you have the `pg_tde` extension installed on both primary and standby.

### A. Primary Server Setup

1. **Configure postgresql.conf for pg_tde:**

    ```ini
    shared_preload_libraries = 'pg_tde'
    pg_tde.key_provider_type = 'file' # Or 'vault', etc.
    pg_tde.keyring_file_path = '/var/lib/postgresql/data/pg_tde_master.key' # Example for file
    # If using Vault, add Vault-specific GUCs
    # pg_tde.vault_addr = 'http://your-vault-server:8200'
    # pg_tde.vault_token = 'your-vault-token-or-auth-path'
    # pg_tde.vault_key_path = 'secret/data/postgres/master_key'
    # pg_tde.master_key_name = 'my_pg_master_key' # Name for the key in Vault
    ```

2. **Configure postgresql.conf for Replication:**

    ```ini
    wal_level = replica
    max_wal_senders = 5
    archive_mode = on # Optional, but good practice
    archive_command = 'cp %p /path/to/archive/%f' # Example archive command
    ```

3. **Create Master Key (if it does not exist):**
    * **For File Provider:** Create an empty file or one with your key if you have it.
        `sudo -u postgres touch /var/lib/postgresql/data/pg_tde_master.key`
        `sudo -u postgres chmod 600 /var/lib/postgresql/data/pg_tde_master.key`
    * **For Vault Provider:** Ensure the key exists in Vault at the configured path and name.
4. **Restart PostgreSQL on Primary.**
5. **Initialize Master Key in psql (if first time):**

    ```sql
    -- For file provider (key name is usually 'default' or derived from filename)
    SELECT pg_tde_master_key_init();
    -- For Vault provider (specify key name)
    -- SELECT pg_tde_master_key_init('my_pg_master_key');
    ```

6. **Enable the pg_tde extension and set tde_heap as default:**

    ```sql
    CREATE EXTENSION pg_tde;
    ALTER SYSTEM SET default_table_access_method = 'tde_heap';
    SELECT pg_reload_conf();
    ```

7. **Create a Replication User:**

    ```sql
    CREATE ROLE replicator REPLICATION LOGIN PASSWORD 'strong_password';
    ```

8. **Configure pg_hba.conf to allow replication connection:**

    ```
    host  replication   replicator    your_standby_ip/32     scram-sha-256
    ```

    Reload `pg_hba.conf`: `SELECT pg_reload_conf();`

9. **Create and Encrypt a Test Table:**

    ```sql
    CREATE TABLE encrypted_stuff (id int primary key, secret_data text);
    -- It will be automatically encrypted if default_table_access_method = 'tde_heap'
    -- Or explicitly: CREATE TABLE encrypted_stuff (...) USING tde_heap;

    INSERT INTO encrypted_stuff VALUES (1, 'My secret data on primary');
    ```

### B. Standby Server Setup

1. **Install PostgreSQL and the pg_tde extension.**
2. **Configure postgresql.conf for pg_tde - IDENTICAL to Primary:**
    Copy the `pg_tde.*` GUCs from the primary's `postgresql.conf` to the standby's `postgresql.conf`.

    ```ini
    shared_preload_libraries = 'pg_tde'
    pg_tde.key_provider_type = 'file'
    pg_tde.keyring_file_path = '/var/lib/postgresql/data/pg_tde_master.key'
    # Or IDENTICAL Vault settings
    ```

3. **Ensure Master Key Accessibility:**
    * **For File Provider:** Securely copy the *exact same master key file* from primary to the standby at the *exact same path* (`/var/lib/postgresql/data/pg_tde_master.key`). Ensure permissions are `600` and owned by the `postgres` user.
    * **For Vault Provider:** Ensure the standby has network connectivity and credentials to access the *same key name* in Vault.
4. **Stop Standby PostgreSQL service (if running).**
5. **Remove any existing data from the standby's data directory.**
6. **Take a Base Backup from Primary:**

    ```bash
    # Run as postgres OS user on the standby server
    pg_basebackup -h your_primary_ip -U replicator -p 5432 -D /var/lib/postgresql/your_data_dir -Fp -Xs -P -R
    # -R creates standby.signal and primary_conninfo in postgresql.auto.conf
    # (For older PG versions, you might need to manually create recovery.conf)
    ```

    Enter the password for `replicator` when prompted.

7. **Start PostgreSQL on Standby.**
    The standby will connect to the primary, start streaming WAL, and apply changes. Because it has the same `pg_tde` configuration and access to the same master key, it will be able to decrypt data.

## 5. Test the Implementation

1. **Follow all steps in Section 4 (A and B) meticulously.**
2. **On the Primary:**
    * Connect via `psql`.
    * Verify the table exists and data can be queried:

        ```sql
        SELECT * FROM encrypted_stuff;
        -- Expected: (1, 'My secret data on primary')
        ```

    * Insert more data:

        ```sql
        INSERT INTO encrypted_stuff VALUES (2, 'Another secret from primary');
        ```

3. **On the Standby:**
    * Wait a few moments for replication to catch up.
    * Connect via `psql`.
    * Check replication status (optional, but good).

        ```sql
        SELECT pg_is_wal_replay_paused(); -- should be false
        SELECT pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn(); -- should be advancing
        ```

    * **Crucial Test:** Query the encrypted table.

        ```sql
        SELECT * FROM encrypted_stuff;
        ```

        **Expected Result:** You should see all data, including the new row.

        ```
         id |         secret_data
        ----+-----------------------------
          1 | My secret data on primary
          2 | Another secret from primary
        (2 rows)
        ```

        If you can query the data successfully, it means the standby was able to decrypt the replicated encrypted blocks using the master key.
    * **Negative Test (Optional):** Temporarily make the master key unavailable on the standby (e.g., rename the key file if using file provider, or revoke Vault access) and restart the standby. Queries to `encrypted_stuff` should now fail with a TDE-related error. Restore the key and restart to confirm functionality returns.

## 6. Limitations and Important Considerations

* **Master Key is Critical:** Loss of the master key means loss of all TDE-encrypted data. Back it up securely and separately.
* **Identical Configuration:** `pg_tde` configuration GUCs (especially those related to key provider and key name/path) **must** be identical on primary and all standbys.
* **Key Provider Accessibility:** The chosen key provider must be accessible from all standby servers with the necessary permissions to fetch the *same* master key.
* **Key Rotation:**
    * When a master key is rotated on the primary, `pg_tde` will manage this. New data is encrypted with the new key (or references to it).
    * For standbys to continue functioning, they must also gain access to this new master key via the key provider. This is usually seamless if using a centralized provider like Vault where the key name remains the same but its version/content changes. For file-based keys, you need to securely distribute the new key file to standbys.
    * Existing data blocks are not typically re-encrypted immediately upon master key rotation. They are re-encrypted when the data pages are next written (e.g., due to an `UPDATE`, `VACUUM FULL`, or `pg_tde_rotate_key_data()` type functions if available for `tde_heap`).
* **Complexity with `tde_heap_basic`:** If you were using `tde_heap_basic` which allows per-table/per-column keys, key management across replicas could be more complex unless all keys are centrally managed and referenced by name from a key provider. `tde_heap` simplifies this by relying on a single master key for table encryption.
* **Promotion:** If a standby is promoted to a new primary, it already has the necessary `pg_tde` configuration and key access, so it will function correctly as a TDE-enabled primary. New standbys built from it will need the same key setup.
