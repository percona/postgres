# Command line tools

The `pg_tde` extension provides new command line tools and modifies some existing tools to work with encrypted WAL and tables.

## pg_tde_change_key_provider

A tool for modifying the configuration of a key provider, possibly also changing its type.

This tool edits the configuration files directly, ignoring permissions or running postgres processes.
It's only intended use is to fix servers that can't be started up because of inaccessible key providers:
for example, when restoring an old backup, when the address of the key provider changed ib the meantime, the tool can be used to correct the configuration, allowing the server to start up.

It should not be used when the server is up and running, in that case, `pg_tde` provides the `pg_tde_change_key_provider_<type>` SQL functions instead.

### Usage

```
pg_tde_change_key_provider [-D <datadir>] <dbOid> <provider_name> <new_provider_type> <provider_parameters...>

  Where <new_provider_type> can be file, vault or kmip

  Depending on the provider type, the additional parameters are:

pg_tde_change_key_provider [-D <datadir>] <dbOid> <provider_name> file <filename>
pg_tde_change_key_provider [-D <datadir>] <dbOid> <provider_name> vault <token> <url> <mount_path> [<ca_path>]
pg_tde_change_key_provider [-D <datadir>] <dbOid> <provider_name> kmip <host> <port> <cert_path> [<ca_path>]
```

## pg_waldump

`pg_waldump` needs to be able to read encrypted WAL records.
To this purpose, it supports the following additional arguments:

`keyring_path`: directory in which to find keyring config files for WAL such files are `pg_tde.map`, `pg_tde.dat`, and `pg_tde_keyrings` (it will not try to decrypt WAL if not set)

## pg_checksums

`pg_checksums` is not able to calculate checksums for encrypted files.
It skips encrypted files, and reports this in the output.