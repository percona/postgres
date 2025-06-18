# Encryption Enforcement

For `pg_tde`, encryption enforcement ensures that only encrypted storage is allowed for specific operations, tables, or the entire database. It prevents the accidental creation of unencrypted tables or indexes in environments where encryption is required for compliance, security, or policy enforcement.

## What does enforcement do?

When enabled, encryption enforcement:

* Prevents creation of unencrypted tables or indexes
* Enforces consistent encryption usage across tenants, databases, or users
* Can be scoped globally, per database, or per role

## Enforce encryption usage

Use the following techniques to enforce the secure use of `pg_tde`.

### 1. Enforce encryption across the server

To enforce encryption cluster-wide, set the [`pg_tde.enforce_encryption`](../variables.md/#pg_tdeenforce_encryption) variable in `postgresql.conf`:

```ini
pg_tde.enforce_encryption = on
```

This ensures that no user, including superusers, can create unencrypted tables unless they explicitly override the variable in a session (see below).

### 2. Enforce encryption for a specific database

To apply encryption enforcement only within a specific database, run:

```sql
ALTER DATABASE example_db SET pg_tde.enforce_encryption = on;
```

This ensures encryption is enforced **only** when connected to that database.

### 3. Enforce encryption for a specific user

You can also enforce encryption on a per-user basis, run:

```sql
ALTER USER example_user SET pg_tde.enforce_encryption = on;
```

This ensures that the user `example_user` cannot create unencrypted tables, regardless of which database they connect to.

### Override enforcement for trusted sessions

Superusers (such as DBAs) can override the variable at the session level:

```sql
SET pg_tde.enforce_encryption = off;
```

This allows temporary creation of unencrypted tables in special cases, such as:

* Loading trusted, public reference datasets
* Benchmarking and test environments
* Migration staging before re-encryption

!!! note
    While superusers can disable enforcement in their session, they must do so explicitly. Enforcement defaults remain active to protect from accidental misconfiguration.
