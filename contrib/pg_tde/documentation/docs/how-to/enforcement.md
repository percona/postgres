# Encryption Enforcement

For `pg_tde`, encryption enforcement ensures that only encrypted storage is allowed for specific operations, tables, or the entire database. It prevents the accidental creation of unencrypted tables or indexes in environments where encryption is required for compliance, security, or policy enforcement.

## How to enforce encryption usage

Use the following techniques to enforce the secure use of `pg_tde`:

### 1. Use encrypted tablespaces exclusively

Create and configure databases/tables to use encrypted tablespaces only. Use permissions or DDL policies to block unencrypted usage.

### 2.

### 3.
