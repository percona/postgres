<!--**Extension Name:** The extension is `pg_tde`.
*   **Table Access Method:** The encrypted table access method is `heap_tde`.
*   **Key Provider GUC:** `pg_tde_key_provider` (e.g., `'file'`, `'vault'`).
*   **File Provider Path GUC:** `pg_tde_file_keys_path` (points to a *directory* where key files are stored, not a single key file).
*   **Master Key Name GUC:** `pg_tde_master_key_name` (this is the logical name of the key, which then maps to a file in `pg_tde_file_keys_path` or an entry in Vault).
*   **Key Management Functions:**
    *   `pg_tde_master_key_add(key_name TEXT, key_value TEXT, key_provider TEXT)`: Adds a key definition. `key_value` can be `NULL` if fetching from an external provider.
    *   `pg_tde_set_master_key(key_name TEXT, provider_name TEXT)`: Sets the active master key for the cluster.
*   **Vault GUCs:** `pg_tde_vault_url`, `pg_tde_vault_token`, `pg_tde_vault_mount_path`, `pg_tde_vault_ca_path`. -->

# Streaming Replication with pg_tde (heap_tde)

This section outlines how to set up PostgreSQL streaming replication when Percona's `pg_tde` extension (specifically the `heap_tde` access method) is enabled on the primary server.

!!! note
    Physical streaming replication copies data blocks directly from the primary to the standby. If these blocks are encrypted on the primary, they arrive **encrypted** on the standby. Therefore, the standby **must** have access to the **exact same encryption keys** as the primary to decrypt and read this data.

## Concepts

* **`pg_tde`:** Percona's extension for Transparent Data Encryption in PostgreSQL.
* **`heap_tde`:** The table access method provided by `pg_tde` that encrypts entire tables using a master key.
* **Master Key:** The central key used by `pg_tde` to encrypt/decrypt data. Identified by a `pg_tde_master_key_name`.
* **Key Provider:** The mechanism `pg_tde` uses to fetch the master key (e.g., local files, HashiCorp Vault). Configured via `pg_tde_key_provider`.

## Set Up Key Provider and Master Key for Replication

The standby server(s) **must** be configured to use the **same key provider settings** and access the **same master key (by name and content)** as the primary server.

### Scenario 1: File-based Key Provider

1. **Primary:**
    * In `postgresql.conf`:

        ```ini
        pg_tde_key_provider = 'file'
        pg_tde_file_keys_path = '/var/lib/postgresql/pg_tde_keys' # Example directory
        pg_tde_master_key_name = 'my_primary_master_key'
        ```

    * Create the directory: `sudo -u postgres mkdir /var/lib/postgresql/pg_tde_keys`
    * `sudo -u postgres chmod 700 /var/lib/postgresql/pg_tde_keys`
    * Place your actual master key file (for example, a file containing a 32-byte AES key) inside this directory, named `my_primary_master_key`:
        `sudo -u postgres dd if=/dev/urandom of=/var/lib/postgresql/pg_tde_keys/my_primary_master_key bs=32 count=1`
        `sudo -u postgres chmod 600 /var/lib/postgresql/pg_tde_keys/my_primary_master_key`
    * After restarting PostgreSQL, in `psql`:

        ```sql
        CREATE EXTENSION IF NOT EXISTS pg_tde; -- If not already done
        -- Add the key definition to pg_tde's catalog (it will read from the file)
        SELECT pg_tde_master_key_add('my_primary_master_key', NULL, 'file');
        -- Set this key as the active master key
        SELECT pg_tde_set_master_key('my_primary_master_key', 'file');
        ```

2. **Standby:**
    * Before starting the standby, **securely copy** the entire `pg_tde_file_keys_path` directory and its contents (specifically the `my_primary_master_key` file) from the primary to the exact same path on the standby (`/var/lib/postgresql/pg_tde_keys`).
    * Ensure permissions on the standby's directory and key file are identical.
    * In the standby's `postgresql.conf`, configure `pg_tde_key_provider`, `pg_tde_file_keys_path`, and `pg_tde_master_key_name` to be **identical** to the primary's configuration.
    * The standby, upon startup, uses these settings to load the key.

### Scenario 2: HashiCorp Vault Key Provider**

1. **Primary:**
    * Ensure the master key (e.g., `my_vault_master_key`) exists in Vault at the configured path (for example, `secret/data/postgres/keys`).
    * In `postgresql.conf`:

        ```ini
        pg_tde_key_provider = 'vault'
        pg_tde_vault_url = 'http://your-vault-server:8200'
        pg_tde_vault_token = 'your-vault-access-token' # Or use other auth methods
        pg_tde_vault_mount_path = 'secret/' # Path where KV engine is mounted
        # pg_tde_vault_ca_path = '/path/to/vault_ca.crt' # If using self-signed certs
        pg_tde_master_key_name = 'my_vault_master_key' # Key name within Vault path
        ```

    * After restarting PostgreSQL, in `psql`:

        ```sql
        CREATE EXTENSION IF NOT EXISTS pg_tde;
        -- Add the key definition (pg_tde will fetch it from Vault)
        SELECT pg_tde_master_key_add('my_vault_master_key', NULL, 'vault');
        -- Set this key as the active master key
        SELECT pg_tde_set_master_key('my_vault_master_key', 'vault');
        ```

2. **Standby:**
    * In the standby's `postgresql.conf`, configure `pg_tde_key_provider` and all `pg_tde_vault_*` parameters, and `pg_tde_master_key_name` to be **identical** to the primary's configuration.
    * Ensure the standby server has network access to the Vault server and the necessary credentials/permissions to read the *same master key* from Vault.
    * The standby, upon startup, uses these settings to load the key.

**Is it possible to use the same key provider and master key?**

**Yes, it is mandatory.** For physical replication to function with TDE, the standby *must* use the same master key (by name and content, accessed via the same provider configuration) as the primary to decrypt the replicated data blocks.

## Encrypted Table Replication

**If a table on the primary site is encrypted, will all the standby sites also have the encrypted table replicated, given that the same key is implemented on the standby sites as well?**

Yes.

Physical replication works at the block level.

1. When you encrypt a table on the primary using `CREATE TABLE ... USING heap_tde;` or by setting `default_table_access_method = 'heap_tde'`, the data blocks on disk are encrypted.
2. Changes to this table (also encrypted) are written to WAL.
3. Streaming replication sends these WAL records to the standby.
4. The standby applies these WAL records, writing the encrypted blocks to its disk.
5. If the standby has the same master key available (via identical `pg_tde` configuration and key access), it can decrypt these blocks when you query the table on the standby.

If the standby lacks the correct key, replicated data remains encrypted and unreadable, and queries will fail.

## Setup Steps

This assumes the `pg_tde` extension is available for installation on both primary and standby.

### A. Primary Server Setup

1. **Install the `pg_tde` extension files.**
2. **Configure `postgresql.conf` for `pg_tde`:**

    ```ini
    shared_preload_libraries = 'pg_tde' // Add pg_tde, comma-separated if others exist

    # Example for File Provider:
    pg_tde_key_provider = 'file'
    pg_tde_file_keys_path = '/var/lib/postgresql/pg_tde_keys'
    pg_tde_master_key_name = 'my_master_key'

    # Example for Vault Provider:
    # pg_tde_key_provider = 'vault'
    # pg_tde_vault_url = 'http://your-vault-server:8200'
    # pg_tde_vault_token = 's.xxxxxxxxxxxxxx'
    # pg_tde_vault_mount_path = 'secret/'
    # pg_tde_master_key_name = 'my_master_key_in_vault'
    ```

3. **Configure `postgresql.conf` for Replication:**

    ```ini
    wal_level = replica
    max_wal_senders = 5
    archive_mode = on # Recommended
    archive_command = 'cp %p /path/to/archive/%f' # Example
    ```

4. **Prepare Master Key in Provider:**

    * **File:** Create the directory specified in `pg_tde_file_keys_path`. Create the key file inside this directory, named as per `pg_tde_master_key_name`.

        ```bash
        sudo -u postgres mkdir -p /var/lib/postgresql/pg_tde_keys
        sudo -u postgres chmod 700 /var/lib/postgresql/pg_tde_keys
        sudo -u postgres dd if=/dev/urandom of=/var/lib/postgresql/pg_tde_keys/my_master_key bs=32 count=1
        sudo -u postgres chmod 600 /var/lib/postgresql/pg_tde_keys/my_master_key
        ```

    * **Vault:** Ensure the key exists in Vault at the correct path and is accessible.
5. **Restart PostgreSQL on Primary.**
6. **Initialize `pg_tde` and Set Master Key (in `psql`):**

    ```sql
    CREATE EXTENSION pg_tde;
    -- Add the key definition to pg_tde's catalog
    -- For File (key_name matches pg_tde_master_key_name and filename):
    SELECT pg_tde_master_key_add('my_master_key', NULL, 'file');
    -- For Vault (key_name matches pg_tde_master_key_name and key name in Vault):
    -- SELECT pg_tde_master_key_add('my_master_key_in_vault', NULL, 'vault');

    -- Set this key as the active master key
    -- For File:
    SELECT pg_tde_set_master_key('my_master_key', 'file');
    -- For Vault:
    -- SELECT pg_tde_set_master_key('my_master_key_in_vault', 'vault');

    -- Set heap_tde as default for new tables (optional)
    ALTER SYSTEM SET default_table_access_method = 'heap_tde';
    SELECT pg_reload_conf();
    ```

7. **Create Replication User & Configure `pg_hba.conf` (standard PostgreSQL steps).**
8. **Create and Encrypt a Test Table:**

    ```sql
    -- If default_table_access_method = 'heap_tde'
    CREATE TABLE encrypted_data (id INT PRIMARY KEY, data TEXT);
    -- Or explicitly:
    -- CREATE TABLE encrypted_data (id INT PRIMARY KEY, data TEXT) USING heap_tde;

    INSERT INTO encrypted_data VALUES (1, 'Secret on primary');
    ```

### B. Standby Server Setup**

1. **Install `pg_tde` extension files.**
2. **Configure `postgresql.conf` for `pg_tde` - IDENTICAL to Primary:**
    Copy the `pg_tde_*` GUCs from the primary's `postgresql.conf` to the standby's `postgresql.conf`. Ensure they are exactly the same.
3. **Ensure Master Key Accessibility:**
    * **File Provider:** Securely copy the *entire key directory* (e.g., `/var/lib/postgresql/pg_tde_keys`) and its contents from primary to the standby at the *exact same path*. Ensure permissions are identical.
    * **Vault Provider:** Ensure standby has network and credential access to the *same key name* in Vault.
4. **Stop Standby PostgreSQL service (if running).**
5. **Remove any existing data from the standby's data directory.**
6. **Take a Base Backup from Primary:**

    ```bash
    # Run as postgres OS user on the standby server
    pg_basebackup -h your_primary_ip -U replicator_user -p 5432 -D /path/to/standby_data_dir -Fp -Xs -P -R
    ```

7. **Start PostgreSQL on Standby.**
    The standby will connect, stream WAL, and apply changes. With identical `pg_tde` config and key access, it will decrypt data.

## Test the Implementation

1. **Follow all steps in Section 4 (A and B) precisely.**
2. **On the Primary:**
    * Insert more data into `encrypted_data`.

        ```sql
        INSERT INTO encrypted_data VALUES (2, 'More secrets from primary');
        ```

3. **On the Standby:**
    * Wait for replication. Connect via `psql`.
    * **Crucial Test:** Query the encrypted table:

        ```sql
        SELECT * FROM encrypted_data;
        ```

        **Expected Result:** You should see all data, including new rows, decrypted successfully.

        ```sql
         id |          data
        ----+-------------------------
          1 | Secret on primary
          2 | More secrets from primary
        (2 rows)
        ```

    * **Negative Test (Optional):** Temporarily make the master key file inaccessible on the standby (e.g., rename `pg_tde_file_keys_path` directory or the key file within it) or revoke Vault token. Restart standby. Queries to `encrypted_data` should now fail with a TDE key access error. Restore access and restart to confirm functionality.

## Limitations and Important Considerations

* **Master Key Security:** The master key is paramount. Securely back it up. For file provider, protect the key file and its directory stringently.
* **Identical Configuration:** All `pg_tde_*` GUCs relevant to key provider and key name **must** be identical on primary and all standbys.
* **Key Rotation (`pg_tde_rotate_master_key`):**
    1. Create/place the new key in your chosen key provider (new file in `pg_tde_file_keys_path` or new key in Vault).
    2. On the primary, add the new key to `pg_tde`'s catalog:
        `SELECT pg_tde_master_key_add('new_master_key_name', NULL, 'your_provider');`
    3. Perform rotation:
        `SELECT pg_tde_rotate_master_key('old_master_key_name', 'new_master_key_name', 'your_provider');`
        This re-encrypts the internal DEKs with the new master key. Data files are re-encrypted lazily or via `pg_tde_encrypt_table()`.
    4. Update `pg_tde_master_key_name` in `postgresql.conf` on the primary to `'new_master_key_name'`.
    5. **Crucially for replication:**
        * Ensure the `new_master_key_name` (and its actual key material) is distributed/accessible to all standbys.
        * Update `pg_tde_master_key_name` in `postgresql.conf` on all standbys to match the primary.
        * A rolling restart of standbys might be necessary after their config and key material are updated.
* **Promotion:** A standby promoted to primary will already have the necessary `pg_tde` setup and key access to function as a TDE-enabled primary.
