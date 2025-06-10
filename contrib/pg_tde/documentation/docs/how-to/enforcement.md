# Encryption Enforcement

For `pg_tde`, encryption enforcement ensures that only encrypted storage is allowed for specific operations, tables, or the entire database. It prevents the accidental creation of unencrypted tables or indexes in environments where encryption is required for compliance, security, or policy enforcement.

## Enforcing encryption usage

Use the following techniques to enforce the secure use of `pg_tde`.

### 1. Use pg_tde.enforce_encryption

The [`pg_tde.enforce_encryption`](../variables.md/#pg_tdeenforce_encryption) option prevents non encrypted tables to be created. 
