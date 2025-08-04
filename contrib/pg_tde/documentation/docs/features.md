# Features

`pg_tde` is available for [Percona Server for PostgreSQL](https://docs.percona.com/postgresql/17/)
The Percona Server for PostgreSQL provides an extended Storage Manager API that allows integration with custom storage managers.

The following features are available for the extension:

* [Table encryption](test.md#encrypt-data-in-a-new-table), including:
    * Data tables
    * Index data for encrypted tables
    * TOAST tables
    * Temporary tables

!!! note
    Metadata of those tables is not encrypted.

* Single-tenancy support via a [global keyring provider](global-key-provider-configuration/set-principal-key.md)
* [Multi-tenancy support](how-to/multi-tenant-setup.md)
* Table-level granularity for encryption and access control
* Multiple [Key management options](global-key-provider-configuration/index.md)

## Related topics

Continue learning or get started with the installation:

<div data-grid markdown><div data-banner markdown>

### :material-progress-download: About Transparent Data Encryption { .title }

Learn what Transparent Data Encryption (TDE) is and how the `pg_tde` extension enables it in PostgreSQL.

[Explore TDE and `pg_tde` :material-arrow-right:](index/about-tde.md){ .md-button }

</div><div data-banner markdown>

### :material-progress-download: Installation guide { .title }

Get started quickly with the step-by-step installation instructions.

[How to install `pg_tde` :material-arrow-right:](install.md){ .md-button }

</div>
