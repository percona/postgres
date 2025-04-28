# Global Key Provider Configuration

In production environments, storing encryption keys locally on the PostgreSQL server can create security risks. To enhance security, `pg_tde` supports integration with external Key Management Systems (KMS) through a Global Key Provider interface.

This section explains how to configure `pg_tde` to use external key providers, including KMIP servers, HashiCorp Vault, local keyring files and more.

!!! note
     KMS integration is optional and it is intended for advanced deployments requiring higher security standards.
