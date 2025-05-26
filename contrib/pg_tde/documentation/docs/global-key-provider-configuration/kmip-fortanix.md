# Fortanix KMIP Server Configuration

`pg_tde` is compatible with Fortanix Data Security Manager (DSM) via the KMIP protocol. For a full setup guide, see [the Fortanix documentation here](https://support.fortanix.com/docs/using-fortanix-data-security-manager-with-edb-postgres-for-tde).

## Recommended Configuration Steps

1. Enable KMIP for your Fortanix DSM instance.
2. Generate or obtain a client certificate and private key from Fortanix DSM.
3. Ensure you store the certificates securely and enable them for PostgreSQL.

## Example Configuration SQL

```sql
SELECT pg_tde_add_global_key_provider_kmip(
    'fortanix_kms_provider',
    'kms.fortanix.com',
    5696,
    '/path/to/fortanix-client-cert.pem',
    '/path/to/fortanix-client-key.pem',
    '/path/to/fortanix-ca-cert.pem'
);
```

!!! note
    Replace the above paths with the actual certificate locations on your PostgreSQL host.
