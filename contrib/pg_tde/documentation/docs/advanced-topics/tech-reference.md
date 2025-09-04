# Technical reference overview

This section covers the internal components and tools that power `pg_tde`.

Use it to understand how encryption is implemented, fine-tune a configuration, leverage advanced CLI tools and functions for diagnostics and customization.

<div data-grid markdown><div data-banner markdown>

### :material-cog-refresh-outline: Architecture { .title }

Explore the internal design of `pg_tde` architecture, including encryption internals, key management, and provider integration.

[Explore the architecture :material-arrow-right:](../architecture/overview.md){.md-button}

</div><div data-banner markdown>

### :material-database-sync: Streaming Replication { .title }

Learn how to configure PostgreSQL streaming replication with `pg_tde` using the `tde_heap` access method. Covers primary and standby setup, key management requirements, and validation steps.

[Set up replication with `tde_heap` :material-arrow-right:](../replication.md){.md-button}

</div><div data-banner markdown>

### :material-tune: GUC Variables { .title }

Configure how `pg_tde` behaves with PostgreSQL. Control WAL encryption, enforce encryption for new tables, and manage global provider inheritance. Includes scope levels, defaults, and permission requirements.

[Configure GUC variables :material-arrow-right:](../variables.md){.md-button}

</div><div data-banner markdown>

### :material-function-variant: Functions { .title }

Use built-in functions to manage key providers, create and rotate principal keys, and verify encryption status. Includes commands for Vault, KMIP, and local providers, plus utilities to inspect or validate keys.

[Browse available functions :material-arrow-right:→](../functions.md){.md-button}

</div></div>
