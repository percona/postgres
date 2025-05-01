# Configure Key Management (KMS)

In production environments, storing encryption keys locally on the PostgreSQL server can introduce security risks. To enhance security, `pg_tde` supports integration with external Key Management Systems (KMS) through a Global Key Provider interface.

This section describes how you can configure `pg_tde` to use the local and external key providers.
To use an external KMS with `pg_tde`, follow these two steps:

1. [Configure a Key Provider](vault.md)(kmip-server.md)(keyring.md)
2. Set the [Global Principal Key](set-principal-key.md)

!!! note
     KMS integration is optional and intended for advanced deployments that require higher security standards.

Select your prefered configuration from the links below:

[Configure KMIP :material-arrow-right:](kmip-server.md){.md-button} [Configure Vault :material-arrow-right:](vault.md){.md-button} [Configure Keyring :material-arrow-right:](keyring.md){.md-button}
