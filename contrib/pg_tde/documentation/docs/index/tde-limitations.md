# Limitations of pg_tde

The following are current limitations of `pg_tde`:

* System tables, which include statistics data and database statistics, are currently **not encrypted**.
* The WAL encryption feature is currently in beta and is not effective unless explicitly enabled. It is not yet production ready. **Do not enable this feature in production environments**.
* `pg_tde` RC 2 is incompatible with `pg_tde` Beta2 due to significant changes in code. There is no direct upgrade flow from one version to another. You must [uninstall](../how-to/uninstall.md) `pg_tde` Beta2 first and then [install](../install.md) and configure the new Release Candidate version.

[Versions and Supported PostgreSQL Deployments](supported-versions.md){.md-button}
