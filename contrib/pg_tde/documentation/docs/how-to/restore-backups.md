# Restoring encrypted backups

To restore an encrypted backup created with an earlier key, ensure the key is still available in your Key Management System (KMS). The backup remains **encrypted** on disk, `pg_tde` uses the correct key to transparently access the data.

Each encrypted table stores metadata that identifies which encryption key was used. When the encrypted data is read, `pg_tde` retrieves the correct key from the configured KMS.

## How `pg_tde` uses old keys to load backups

* **KMS**: stores the key that was active when the backup was made.
* **Encrypted backup**: contains data encrypted with the key available at that time.
* **Current server**: `pg_tde` automatically loads the backup if the key is accessible through the KMS.

At runtime, `pg_tde` reads the key ID from the table metadata and fetches the corresponding key from the KMS.

!!! note
    If the key was deleted or the KMS configuration changed, the backup **cannot** be read. Use [pg_tde_change_key_provider](../command-line-tools/pg-tde-change-key-provider.md) to update KMS credentials or endpoints if needed.
