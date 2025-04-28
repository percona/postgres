# `pg_tde` documentation

`pg_tde` is the open source, community driven and futureproof PostgreSQL extension that provides Transparent Data Encryption (TDE) to protect data at rest. `pg_tde` ensures that the data stored on disk is encrypted, and that no one can read it without the proper encryption keys, even if they gain access to the physical storage media.

Learn more about [what Transparent Data Encryption is](tde.md#how-does-it-work) and [why do you need it](tde.md#why-do-you-need-tde).

!!! important

    This is the {{release}} version of the extension and it is not meant for production use yet. We encourage you to use it in testing environments and [provide your feedback](https://forums.percona.com/c/postgresql/pg-tde-transparent-data-encryption-tde/82). 

[About TDE](overview/tde-encrypts.md){.md-button}
[Get started](install.md){.md-button}
[What's new in pg_tde {{release}}](release-notes/release-notes.md){.md-button}