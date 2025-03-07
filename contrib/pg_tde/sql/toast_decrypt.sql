CREATE EXTENSION IF NOT EXISTS pg_tde;

SELECT pg_tde_add_key_provider_file('file-vault','/tmp/pg_tde_test_keyring.per');
SELECT pg_tde_set_principal_key('test-db-principal-key','file-vault');

CREATE TABLE src (f1 TEXT STORAGE EXTERNAL) USING tde_heap;
INSERT INTO src VALUES(repeat('abcdeF',1000));
SELECT * FROM src;

DROP TABLE src;

DROP EXTENSION pg_tde;
