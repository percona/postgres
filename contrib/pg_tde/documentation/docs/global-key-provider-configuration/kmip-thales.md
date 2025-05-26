# Thales KMIP Server Configuration

To use the Python library pykmip for cryptographic operations with Thales CipherTrust Manager, see Using pykmip in the Implementing Thales CipherTrust Manager documentation for instructions. pykmip is a Python library that implements the KMIP industry standard for key management operations.

https://www.enterprisedb.com/docs/partner_docs/ThalesCipherTrustManager/
https://www.enterprisedb.com/docs/partner_docs/ThalesCipherTrustManager/05-UsingThalesCipherTrustManager/

## Recommended Configuration Steps

1.
2.
3.

## Example Configuration SQL

```sql
SELECT pg_tde_add_global_key_provider_kmip(
    'thales_kmip_provider',
    'kmip.thales.local',
    5696,
    '/path/to/thales-client-cert.pem',
    '/path/to/thales-client-key.pem',
    '/path/to/thales-ca-cert.pem'
);
```

!!! note
    Replace the above paths with the actual certificate locations on your PostgreSQL host.
