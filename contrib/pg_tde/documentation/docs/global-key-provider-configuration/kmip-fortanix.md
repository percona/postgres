# Fortanix KMIP Server Configuration

`pg_tde` is compatible with Fortanix Data Security Manager (DSM) via the KMIP protocol. For a full setup guide, see [the Fortanix KMIP documentation here](https://support.fortanix.com/docs/users-guide-account-client-configurations?highlight=KMIP#23-kmip-clients).

For more information on adding or modifying the provider, see the [Adding or modifying KMIP providers](https://docs.percona.com/pg-tde/functions.html?h=pg_tde_add_global_key_provider_kmip#adding-or-modifying-kmip-providers) topic.

## Example Configuration SQL

!!! note
    Replace 'your-region.kms.fortanix.com' with the actual KMIP endpoint for your Fortanix DSM instance.
    Fortanix uses region-specific or tenant-specific KMIP domains (e.g., eu.kms.fortanix.com, us.kms.fortanix.com).
    Refer to your DSM dashboard or administrator to confirm the correct value.

!!! note
    Replace the above paths with the actual certificate locations on your PostgreSQL host.
