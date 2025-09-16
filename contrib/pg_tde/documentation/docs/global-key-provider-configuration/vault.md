# Vault configuration

You can configure `pg_tde` to use HashiCorp Vault as a global key provider for managing encryption keys securely. Both the open source and enterprise editions are supported. `pg_tde` only supports the HashiCorp Vault back end with KV Secrets Engine - Version 2 (API) with versioning enabled.

!!! note
    This guide assumes that your Vault server is already set up and accessible. Vault configuration is outside the scope of this document, see [Vault's official documentation](https://developer.hashicorp.com/vault/docs) or [KV secrets engine - version 2 (API)](https://developer.hashicorp.com/vault/api-docs/secret/kv/kv-v2) for more information.

## Example usage

```sql
SELECT pg_tde_add_global_key_provider_vault_v2(
    'provider-name',
    'url',
    'mount',
    'secret_token_path',
    'ca_path'
);
```

## Parameter descriptions

* `provider-name` is the name to identify this key provider
* `secret_token_path` is a path to the file that contains an access token with read and write access to the above mount point
* `url` is the URL of the Vault server
* `mount` is the mount point where the keyring should store the keys
* [optional] `ca_path` is the path of the CA file used for SSL verification

The following example is for testing purposes only. Use secure tokens and proper SSL validation in production environments:

```sql
SELECT pg_tde_add_global_key_provider_vault_v2(
    'my-vault',
    'https://vault.vault.svc.cluster.local:8200',
    'secret/data',
    '/path/to/token_file',
    '/path/to/ca_cert.pem'
);
```

!!! note
    For more information on related functions, see [Functions](../functions.md) topic.

## Required permissions

`pg_tde` requires given permissions on listed Vault's API endpoints:

* `sys/mounts/<mount>` - **read** permissions
* `<mount>/data/*` - **create**, **read** permissions
* `<mount>/metadata` - **list** permissions

!!! note
    For more information on Vault permissions, see the [following documentation](https://developer.hashicorp.com/vault/docs/concepts/policies).

## Next steps

[Set up the Global principal key :material-arrow-right:](set-principal-key.md){.md-button}
