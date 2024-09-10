This is a very basic dockerfile for testing pg_tde

To build run:

```
docker build . --tag 'pgtde'
```

To use it, for example:

```
docker run -p 5432:5432 --name tde -d pgtde 

docker exec -it pgtde bin/createdb test
# Enter password: "pg"
docker exec -it pgtde bin/psql test
# Enter password: "pg"
```

After that, TDE is usable in the psql terminal:

```sql
CREATE EXTENSION pg_tde;
SELECT pg_tde_add_key_provider_file('file-vault','/tmp/pg_tde_test_keyring.per');
SELECT pg_tde_set_principal_key('test-db-principal-key','file-vault');

CREATE TABLE test_enc1(
	  id SERIAL,
	  k INTEGER DEFAULT '0' NOT NULL,
	  PRIMARY KEY (id)
	) USING tde_heap_basic;

CREATE TABLE test_enc2(
	  id SERIAL,
	  k INTEGER DEFAULT '0' NOT NULL,
	  PRIMARY KEY (id)
	) USING tde_heap;
```
