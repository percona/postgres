# Thales KMIP Server Configuration

`pg_tde` is compatible with the Thales CipherTrust Manager via the KMIP protocol. For a full setup guide, see [the following documentation](https://thalesdocs.com/ctp/cm/2.19/reference/kmip-ref/index.html?).

## Recommended Configuration Steps

1. Obtain and secure the certificates from Thales CipherTrust Manager.
2. Create `pykmip.conf`.
3. Configure PostgreSQL for pg_tde + KMIP.
4. Create or Retrieve the KMIP Key.

## Example Configuration SQL

```sql
SELECT pg_tde_add_global_key_provider_kmip(
    'thales_kmip_provider',
    'kmip.example.org',
    5696,
    '/path/to/thales-client-cert.pem',
    '/path/to/thales-client-key.pem',
    '/path/to/thales-ca-cert.pem'
);
```

!!! note
    Replace the example paths and parameters with the actual certificate locations on your PostgreSQL host.
