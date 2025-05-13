# Fortanix KMIP Server Configuration

`pg_tde` has been tested and confirmed compatible with Fortanix DSM (Data Security Manager) using the KMIP protocol. Use the following parameters to configure Fortanix DSM as your KMIP server:

| Parameter            | Description                                                       | Example                                 |
|----------------------|-------------------------------------------------------------------|-----------------------------------------|
| `host`               | Hostname or IP address of your Fortanix DSM KMIP server.          | `kms.fortanix.com`                      |
| `port`               | KMIP server port (usually `5696`).                                | `5696`                                  |
| `client_certificate` | Path to your Fortanix DSM-issued client certificate (PEM format). | `/path/to/fortanix-client-cert.pem`     |
| `client_key`         | Path to the client certificate's private key.                     | `/path/to/fortanix-client-key.pem`      |
| `ca_certificate`     | Path to the Fortanix DSM CA certificate for verifying the server. | `/path/to/fortanix-ca-cert.pem`         |

## Recommended Configuration Steps

1. Ensure your Fortanix DSM is properly set up with KMIP enabled.
2. Generate or obtain a client certificate and private key from your Fortanix DSM instance.
3. Save your client certificate, private key, and the Fortanix CA certificate securely and reference these files in your configuration.

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
