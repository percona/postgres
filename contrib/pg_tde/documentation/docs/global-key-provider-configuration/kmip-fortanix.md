# Fortanix KMIP Server Configuration

`pg_tde` is compatible with Fortanix Data Security Manager (DSM) via the KMIP protocol. For a full setup guide, see [the Fortanix KMIP documentation here](https://support.fortanix.com/docs/users-guide-account-client-configurations?highlight=KMIP#23-kmip-clients).

## Recommended Configuration Steps

1. Obtain a client certificate, private key, and CA certificate from Fortanix DSM.
2. Ensure you store the certificates securely.
3. Register Fortanix DSM with `pg_tde`, see [the following example](#example-configuration-sql).
4. Enable `pg_tde` and restart PostgreSQL, see [the following topic](../setup.md#configure-pg_tde).

## Example Configuration SQL

```sql
SELECT pg_tde_add_global_key_provider_kmip(
    'fortanix_kms_provider',
    'your-region.kms.fortanix.com', -- Replace with your actual Fortanix DSM endpoint
    5696,
    '/path/to/fortanix-client-cert.pem',
    '/path/to/fortanix-client-key.pem',
    '/path/to/fortanix-ca-cert.pem'
);
```

!!! note
    Replace 'your-region.kms.fortanix.com' with the actual KMIP endpoint for your Fortanix DSM instance.
    Fortanix uses region-specific or tenant-specific KMIP domains (e.g., eu.kms.fortanix.com, us.kms.fortanix.com).
    Refer to your DSM dashboard or administrator to confirm the correct value.

!!! note
    Replace the above paths with the actual certificate locations on your PostgreSQL host.
