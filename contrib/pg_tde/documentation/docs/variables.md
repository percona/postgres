# GUC Variables

The `pg_tde` extension provides GUC variables to configure the behaviour of the extension:

## pg_tde.wal_encrypt

A `boolean` variable controlling if WAL writes are encrypted or not.

Changing this variable requires a server restart, and can only be set at the server level.

WAL encryption is controlled globally, if enabled all WAL writes are encrypted.

This variable only controls new writes to the WAL, it doens't affect existing WAL records.
`pg_tde` is always capable of reading existing encrypted WAL records, as long as the keys used for the encryption are still available.



Enabling WAL encryption requires a configured global principal key.

The default value is false.

## pg_tde.enforce_encryption

A `boolean` variable controlling if creation of new not encrypted tables is enabled or not.

This can be set at global, database, user or session level, but changing the value requires superuser permissions.

If enabled, `CREATE TABLE` statements will fail unless they use the `tde_heap` access method.

Similarly, `ALTER TABLE <x> SET ACCESS METHOD` is only allowed, if the access method is `tde_heap`.

Other DDL operations are still allowed, for example other `ALTER` commands are allowed on unencrypted tables, as long as the access method isn't changed.

The default value is false.

## pg_tde.inherit_global_providers

A `boolean` variable controlling if databases can use global key providers for storing principal keys.

This can be set at global, database, user or session level, but changing the value requires superuser permissions.

If disabled, functions that change the key providers can only work with database local key providers.
In this case, the default principal key, if set, is also disabled.

This doesn't affect existing uses of global keys, only prevents the creation of new principal keys using global providers.

The default value is true.