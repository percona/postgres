# Keyring file configuration

This setup is intended for development and stores the keys unencrypted in a data file you specify.

!!! note
     While keyring files may be acceptable for **local** or **testing environments**, KMS integration is the recommended approach for production deployments.

In order to configure a simple keyring file with a local key, use the following steps:

1. Create a key provider (`file-keyring` in this example) in the `/tmp/pg_tde_test_local_keyring.per` file:

    ```sql
    SELECT pg_tde_add_global_key_provider_file(
        'file-keyring',
        '/tmp/pg_tde_test_local_keyring.per'
    );
    ```

2. Create a key (`my_default_key` in this example) inside the newly created `file-keyring` provider:

    ```sql
    SELECT pg_tde_create_key_using_global_key_provider(
    'my_default_key',
    'file-keyring'
    );
    ```

3. Now, set the key (`my_default_key`) from the key provider (`file-keyring`). You need to set your key before encryption starts:

    ```sql
    SELECT pg_tde_set_key_using_global_key_provider(
    'my_default_key',
    'file-keyring'
    );
    ```

!!! tip
    You can check the default key information (such as the date and time of creation), run:

    ```sql
    SELECT pg_tde_default_key_info();
    ```

4. Now, create a table using [tde_heap](../index/table-access-method.md#how-tde_heap-works-with-pg_tde):

```sql
CREATE TABLE test1(a INT) USING tde_heap;
```

The newly created table is encrypted with the default key you have set (`my_default_key`).

!!! tip
    To check if your created table is encrypted with tde_heap, run:

    ```sql
    \d+ test1
    ```

If the access method is `tde_heap`, then your table is encrypted.

??? "Example output"
        postgres=# \d+ test1
                                            Table "public.test1"
    Column |  Type   | Collation | Nullable | Default | Storage | Compression | Stats target | Description 
    --------+---------+-----------+----------+---------+---------+-------------+--------------+-------------
    a      | integer |           |          |         | plain   |             |              | 
    Access method: tde_heap

## Further reading

Now you can check out how to further [configure the global principal key](set-principal-key.md).

Alternatively, you can skip directly to learn how to [validate encryption with pg_tde](../test.md) or how to [configure WAL encryption](../wal-encryption.md).

You can also verify the functions that come with `pg_tde` in [Functions](../functions.md).
