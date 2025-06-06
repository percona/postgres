# Handling Key Rotation and Encrypted Backups

Backups created with `pg_tde` are encrypted using the *active principal key* at the time of backup. If this key is rotated and the original version is not retained, those backups **can no longer be decrypted**. This makes **secure key storage** essential for reliable disaster recovery.

## Why you must store old principal keys

Each time you rotate the principal key, you create a potential split in decryption compatibility:

- New backups will be encrypted with the new key.
- Old backups **require** the key that was active at the time they were created.

!!! important
    Losing access to an old principal key means **permanent data loss** for the associated backups.

## How to store principal keys securely

We recommend using a dedicated [Key Management System (KMS)](../global-key-provider-configuration/index.md). The KMS provides:

- Secure, access-controlled key storage.
- An audit trail for compliance and traceability.
- Support for versioning and key rotation policies.

## Example: Using HashiCorp Vault to store rotated keys

Here’s a basic workflow using the **KV v2 secrets engine**:

1. Enable the secrets engine by following the [Vault KV documentation](https://developer.hashicorp.com/vault/docs/commands/kv).
2. Store your current principal key.
3. When rotating, generate and store a new principal key under a new version or path.

## How to Restore a Backup Using an Old Key

To decrypt a backup made with a previous principal key:

1. Retrieve the correct principal key used at the time of backup from your key management system.
2. Configure `pg_tde` to use this key temporarily.
3. Restore the backup as usual.
4. (Optional) After the restore, re-encrypt the data using the latest principal key.
