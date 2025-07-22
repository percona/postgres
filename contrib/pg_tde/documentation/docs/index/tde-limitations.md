# Limitations of pg_tde

* Keys in the local keyfile are stored **unencrypted**. For better security we recommend using the [Key management storage](../global-key-provider-configuration/index.md).
* System tables, which include statistics data and database statistics, are currently **not encrypted**.
* The WAL encryption feature is currently in beta and is not effective unless explicitly enabled.
* `pg_tde` RC 2 is incompatible with `pg_tde` Beta2 due to significant changes in code. There is no direct upgrade flow from one version to another. You must [uninstall](../how-to/uninstall.md) `pg_tde` Beta2 first and then [install](../install.md) and configure the new Release Candidate version.

[Versions and Supported PostgreSQL Deployments](supported-versions.md){.md-button}
