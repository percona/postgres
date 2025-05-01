# Configure local keyring file

This setup is intended for development and stores the keys unencrypted in the specified data file. See [how to use external reference to parameters](../how-to/external-parameters.md) to add an extra security layer to your setup.
  
```sql
    SELECT pg_tde_add_global_key_provider_file(
        'provider-name',
        '/path/to/the/keyring/data.file'
    );
```

<i note>:material-information: Note:</i> The following example is used for testing purposes only:

```sql
    SELECT pg_tde_add_global_key_provider_file(
        'file-keyring',
        '/tmp/pg_tde_test_local_keyring.per'
    );
```

## Next Step

[Test pg_tde :material-arrow-right:](../test.md){.md-button}