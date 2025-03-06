# GUC Variables

The `pg_tde` extension provides GUC variables to configure the behaviour of the extension:

## pg_tde.wal_encrypt

**Type** - boolean <br>
**Default** - off

A `boolean` variable controlling if WAL writes are encrypted or not.

Changing this variable requires a server restart, and can only be set at the server level.

WAL encryption is controlled globally. If enabled, all WAL writes are encrypted in the entire PostgreSQL cluster.

This variable only controls new writes to the WAL, it doesn't affect existing WAL records.

`pg_tde` is always capable of reading existing encrypted WAL records, as long as the keys used for the encryption are still available.

Enabling WAL encryption requires a configured global principal key. Refer to the [WAL encryption configuration](wal-encription.md) documentation for more information.

## pg_tde.enforce_encryption

**Type** - boolean <br>
**Default** - off

A `boolean` variable controlling if the creation of new not encrypted tables is enabled or not.

If enabled, `CREATE TABLE` statements will fail unless they use the `tde_heap` access method.

Similarly, `ALTER TABLE <x> SET ACCESS METHOD` is only allowed, if the access method is `tde_heap`.

Other DDL operations are still allowed. For example other `ALTER` commands are allowed on unencrypted tables, as long as the access method isn't changed.

You can set this variable at the following levels. 

* global - for the entire PostgreSQL cluster
* database - for the current database
* user - 
* session - for the current user session.

Setting or changing the value requires superuser permissions.

## pg_tde.inherit_global_providers

**Type** - boolean <br>
**Default** - on

A `boolean` variable controlling if databases can use global key providers for storing principal keys.

This can be set at global, database, user or session level, but changing the value requires superuser permissions.

If disabled, functions that change the key providers can only work with database local key providers.
In this case, the default principal key, if set, is also disabled.

This doesn't affect existing uses of global keys. It only prevents the creation of new principal keys using global providers.

The default value is true.