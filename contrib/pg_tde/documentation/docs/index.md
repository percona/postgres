# `pg_tde` documentation

`pg_tde` is the open source PostgreSQL extension that provides Transparent Data Encryption (TDE) to protect data at rest. This ensures that the data stored on disk is encrypted, and no one can read it without the proper encryption keys, even if they gain access to the physical storage media. 

Learn more [what Transparent Data Encryption is](tde.md#how-does-it-work) and [why you need it](tde.md#why-do-you-need-tde).

!!! important 

    This is the {{release}} version of the extension and it is not meant for production use yet. We encourage you to use it in testing environments and [provide your feedback](https://forums.percona.com/c/postgresql/pg-tde-transparent-data-encryption-tde/82). 

[TDE Overview](tde_encrypts.md){.md-button}    
[Get started](install.md){.md-button}
[What's new in pg_tde {{release}}](release-notes/release-notes.md){.md-button}