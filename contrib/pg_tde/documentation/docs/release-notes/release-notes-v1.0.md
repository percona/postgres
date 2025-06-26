# pg_tde 1.0 ({{date.GA10}})

`pg_tde` extension brings in [Transparent Data Encryption (TDE)](../index/index.md) to PostgreSQL and enables you to keep sensitive data safe and secure.

[Get Started](../install.md){.md-button}

## Release Highlights

This release provides the following features and improvements:

* **Major documentation updates**

The `pg_tde` documentation has received significant updates, which include:

- New KMS configuration guides for Fortanix, Vault, KMIP and OpenBAO
- Reorganized and expanded topics for Architecture, GUC, Functions and FAQ
- Extensive and numerous refinements and clarifications across the entire site

Explore the full documentation [in the official `pg_tde` documentations](https://docs.percona.com/pg-tde/index.html).

## Upgrade considerations

`pg_tde` {{tdeversion}} is **not** backward compatible with previous `pg_tde` versions, like Release Candidate 2, due to significant changes in code. This means you **cannot** directly upgrade from one version to another. You must do **a clean installation** of `pg_tde`.

## Known issues

* The default `mlock` limit on Rocky Linux 8 for ARM64-based architectures equals the memory page size and is 64 Kb. This results in the child process with `pg_tde` failing to allocate another memory page because the max memory limit is reached by the parent process.

To prevent this, you can change the `mlock` limit to be at least twice bigger than the memory page size:

* temporarily for the current session using the `ulimit -l <value>` command.
* set a new hard limit in the `/etc/security/limits.conf` file. To do so, you require the superuser privileges.

Adjust the limits with caution since it affects other processes running in your system.

## Changelog

### New Features

## Improvements

### Bugs Fixed
