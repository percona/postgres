# Encryption Enforcement

`pg_tde` transparently encrypts user data at rest using a tablespace-level key hierarchy. However, **encryption is not retroactive**, and not all operations are automatically restricted unless enforcement is configured.

This section explains how to **ensure data is encrypted** and how to **prevent insecure usage patterns**.

## What is encrypted

By default, `pg_tde` encrypts:

- Data files stored in encrypted tablespaces
- WAL segments if WAL encryption is enabled
- Temporary files (if using encrypted temporary tablespaces)

## What is **not** automatically encrypted

- Tables created outside an encrypted tablespace
- System catalogs
- Extensions and unlogged tables
- Old backups made before encryption was configured

## How to Enforce Encryption Usage

Use the following techniques to enforce secure use of TDE:

### 1. Use Encrypted Tablespaces Exclusively

Create and configure databases/tables to use encrypted tablespaces only. Use permissions or DDL policies to block unencrypted usage.

### 2. Use Hooks to Reject Unsafe Operations

Enable or develop PostgreSQL hooks that prevent:
- Table creation in unencrypted tablespaces
- Execution of unsafe DDL

> Note: This may require a custom extension or policy enforcement layer.

### 3. Monitor with `pg_tde` Functions

Use internal functions to verify encryption:
```sql
SELECT * FROM pg_tde_tablespace_status();
