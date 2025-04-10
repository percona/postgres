CREATE EXTENSION IF NOT EXISTS pg_tde;

SELECT pg_tde_add_global_key_provider_file('global_keyring_provider','/tmp/keyring.per');

SELECT pg_tde_set_principal_key_using_global_key_provider('principal_key_using_global_key_provider','global_keyring_provider');

CREATE TABLE encrypted_table (
    id SERIAL,
    data TEXT,
    created_at DATE NOT NULL,
    PRIMARY KEY (id, created_at)
) USING tde_heap;

CREATE INDEX idx_date ON encrypted_table (created_at);

SELECT pg_tde_is_encrypted('encrypted_table');
CLUSTER encrypted_table USING idx_date;
SELECT pg_tde_is_encrypted('encrypted_table');

DROP EXTENSION pg_tde CASCADE;


