CREATE EXTENSION IF NOT EXISTS pg_tde;

SELECT pg_tde_add_key_provider_file('PG_TDE_GLOBAL', 'file-provider','/tmp/pg_tde_regression_default_principal_key.per');

SELECT pg_tde_set_default_principal_key('default-principal-key', 'PG_TDE_GLOBAL', 'file-provider', false);

-- fails
SELECT pg_tde_delete_key_provider('PG_TDE_GLOBAL', 'file-provider');
SELECT id, provider_name FROM pg_tde_list_all_key_providers('PG_TDE_GLOBAL');

-- Should fail: no principal key for the database yet
SELECT  key_provider_id, key_provider_name, principal_key_name
		FROM pg_tde_principal_key_info();
 
-- Should succeed: "localizes" the default principal key for the database
CREATE TABLE test_enc(
	id SERIAL,
	k INTEGER DEFAULT '0' NOT NULL,
	PRIMARY KEY (id)
) USING tde_heap;

INSERT INTO test_enc (k) VALUES (1), (2), (3);

-- Should succeed: create table localized the principal key
SELECT  key_provider_id, key_provider_name, principal_key_name
		FROM pg_tde_principal_key_info();

CREATE DATABASE regress_pg_tde_other;

\c regress_pg_tde_other

CREATE EXTENSION pg_tde;

-- Should fail: no principal key for the database yet
SELECT  key_provider_id, key_provider_name, principal_key_name
		FROM pg_tde_principal_key_info();

-- Should succeed: "localizes" the default principal key for the database
CREATE TABLE test_enc(
	id SERIAL,
	k INTEGER DEFAULT '0' NOT NULL,
	PRIMARY KEY (id)
) USING tde_heap;

INSERT INTO test_enc (k) VALUES (1), (2), (3);

-- Should succeed: create table localized the principal key
SELECT  key_provider_id, key_provider_name, principal_key_name
		FROM pg_tde_principal_key_info();

\c regression_pg_tde

SELECT pg_tde_set_default_principal_key('new-default-principal-key', 'PG_TDE_GLOBAL', 'file-provider', false);

SELECT  key_provider_id, key_provider_name, principal_key_name
		FROM pg_tde_principal_key_info();

\c regress_pg_tde_other

SELECT  key_provider_id, key_provider_name, principal_key_name
		FROM pg_tde_principal_key_info();

DROP TABLE test_enc;

DROP EXTENSION pg_tde CASCADE;

\c regression_pg_tde

DROP TABLE test_enc;

DROP EXTENSION pg_tde CASCADE;

DROP DATABASE regress_pg_tde_other;
