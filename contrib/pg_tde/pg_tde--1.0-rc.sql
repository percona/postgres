/* contrib/pg_tde/pg_tde--1.0-rc.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_tde" to load this file. \quit

-- Key Provider Management
CREATE FUNCTION pg_tde_add_key_provider(provider_type TEXT, provider_name TEXT, options JSON)
RETURNS INT
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_add_key_provider_file(provider_name TEXT, file_path TEXT)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_file_keyring_provider_options function.
    SELECT pg_tde_add_key_provider('file', provider_name,
                json_object('type' VALUE 'file', 'path' VALUE COALESCE(file_path, '')));
END;

CREATE FUNCTION pg_tde_add_key_provider_file(provider_name TEXT, file_path JSON)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_file_keyring_provider_options function.
    SELECT pg_tde_add_key_provider('file', provider_name,
                json_object('type' VALUE 'file', 'path' VALUE file_path));
END;

CREATE FUNCTION pg_tde_add_key_provider_vault_v2(provider_name TEXT,
                                                vault_token TEXT,
                                                vault_url TEXT,
                                                vault_mount_path TEXT,
                                                vault_ca_path TEXT)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_vaultV2_keyring_provider_options function.
    SELECT pg_tde_add_key_provider('vault-v2', provider_name,
                            json_object('type' VALUE 'vault-v2',
                            'url' VALUE COALESCE(vault_url, ''),
                            'token' VALUE COALESCE(vault_token, ''),
                            'mountPath' VALUE COALESCE(vault_mount_path, ''),
                            'caPath' VALUE COALESCE(vault_ca_path, '')));
END;

CREATE FUNCTION pg_tde_add_key_provider_vault_v2(provider_name TEXT,
                                                vault_token JSON,
                                                vault_url JSON,
                                                vault_mount_path JSON,
                                                vault_ca_path JSON)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_vaultV2_keyring_provider_options function.
    SELECT pg_tde_add_key_provider('vault-v2', provider_name,
                            json_object('type' VALUE 'vault-v2',
                            'url' VALUE vault_url,
                            'token' VALUE vault_token,
                            'mountPath' VALUE vault_mount_path,
                            'caPath' VALUE vault_ca_path));
END;

CREATE FUNCTION pg_tde_add_key_provider_kmip(provider_name TEXT,
                                             kmip_host TEXT,
                                             kmip_port INT,
                                             kmip_ca_path TEXT,
                                             kmip_cert_path TEXT)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_kmip_keyring_provider_options function.
    SELECT pg_tde_add_key_provider('kmip', provider_name,
                            json_object('type' VALUE 'kmip',
                            'host' VALUE COALESCE(kmip_host, ''),
                            'port' VALUE kmip_port,
                            'caPath' VALUE COALESCE(kmip_ca_path, ''),
                            'certPath' VALUE COALESCE(kmip_cert_path, '')));
END;

CREATE FUNCTION pg_tde_add_key_provider_kmip(provider_name TEXT,
                                             kmip_host JSON,
                                             kmip_port JSON,
                                             kmip_ca_path JSON,
                                             kmip_cert_path JSON)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_kmip_keyring_provider_options function.
    SELECT pg_tde_add_key_provider('kmip', provider_name,
                            json_object('type' VALUE 'kmip',
                            'host' VALUE kmip_host,
                            'port' VALUE kmip_port,
                            'caPath' VALUE kmip_ca_path,
                            'certPath' VALUE kmip_cert_path));
END;

CREATE FUNCTION pg_tde_set_default_principal_key(principal_key_name TEXT, provider_name TEXT DEFAULT NULL, ensure_new_key BOOLEAN DEFAULT FALSE)
RETURNS boolean
AS 'MODULE_PATHNAME'
LANGUAGE C;

CREATE FUNCTION pg_tde_list_all_key_providers
    (OUT id INT,
    OUT provider_name TEXT,
    OUT provider_type TEXT,
    OUT options JSON)
RETURNS SETOF record
LANGUAGE C STRICT
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_list_all_global_key_providers
    (OUT id INT,
    OUT provider_name TEXT,
    OUT provider_type TEXT,
    OUT options JSON)
RETURNS SETOF record
LANGUAGE C STRICT
AS 'MODULE_PATHNAME';

-- Global Tablespace Key Provider Management
CREATE FUNCTION pg_tde_add_global_key_provider(provider_type TEXT, provider_name TEXT, options JSON)
RETURNS INT
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_add_global_key_provider_file(provider_name TEXT, file_path TEXT)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_file_keyring_provider_options function.
    SELECT pg_tde_add_global_key_provider('file', provider_name,
                json_object('type' VALUE 'file', 'path' VALUE COALESCE(file_path, '')));
END;

CREATE FUNCTION pg_tde_add_global_key_provider_file(provider_name TEXT, file_path JSON)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_file_keyring_provider_options function.
    SELECT pg_tde_add_global_key_provider('file', provider_name,
                json_object('type' VALUE 'file', 'path' VALUE file_path));
END;

CREATE FUNCTION pg_tde_add_global_key_provider_vault_v2(provider_name TEXT,
                                                        vault_token TEXT,
                                                        vault_url TEXT,
                                                        vault_mount_path TEXT,
                                                        vault_ca_path TEXT)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_vaultV2_keyring_provider_options function.
    SELECT pg_tde_add_global_key_provider('vault-v2', provider_name,
                            json_object('type' VALUE 'vault-v2',
                            'url' VALUE COALESCE(vault_url, ''),
                            'token' VALUE COALESCE(vault_token, ''),
                            'mountPath' VALUE COALESCE(vault_mount_path, ''),
                            'caPath' VALUE COALESCE(vault_ca_path, '')));
END;

CREATE FUNCTION pg_tde_add_global_key_provider_vault_v2(provider_name TEXT,
                                                        vault_token JSON,
                                                        vault_url JSON,
                                                        vault_mount_path JSON,
                                                        vault_ca_path JSON)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_vaultV2_keyring_provider_options function.
    SELECT pg_tde_add_global_key_provider('vault-v2', provider_name,
                            json_object('type' VALUE 'vault-v2',
                            'url' VALUE vault_url,
                            'token' VALUE vault_token,
                            'mountPath' VALUE vault_mount_path,
                            'caPath' VALUE vault_ca_path));
END;

CREATE FUNCTION pg_tde_add_global_key_provider_kmip(provider_name TEXT,
                                                    kmip_host TEXT,
                                                    kmip_port INT,
                                                    kmip_ca_path TEXT,
                                                    kmip_cert_path TEXT)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_kmip_keyring_provider_options function.
    SELECT pg_tde_add_global_key_provider('kmip', provider_name,
                            json_object('type' VALUE 'kmip',
                            'host' VALUE COALESCE(kmip_host, ''),
                            'port' VALUE kmip_port,
                            'caPath' VALUE COALESCE(kmip_ca_path, ''),
                            'certPath' VALUE COALESCE(kmip_cert_path, '')));
END;

CREATE FUNCTION pg_tde_add_global_key_provider_kmip(provider_name TEXT,
                                                    kmip_host JSON,
                                                    kmip_port JSON,
                                                    kmip_ca_path JSON,
                                                    kmip_cert_path JSON)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_kmip_keyring_provider_options function.
    SELECT pg_tde_add_global_key_provider('vault-v2', provider_name,
                            json_object('type' VALUE 'vault-v2',
                            'host' VALUE kmip_host,
                            'port' VALUE kmip_port,
                            'caPath' VALUE kmip_ca_path,
                            'certPath' VALUE kmip_cert_path));
END;

-- Key Provider Management
CREATE FUNCTION pg_tde_change_key_provider(provider_type TEXT, provider_name TEXT, options JSON)
RETURNS INT
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_change_key_provider_file(provider_name TEXT, file_path TEXT)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_file_keyring_provider_options function.
    SELECT pg_tde_change_key_provider('file', provider_name,
                json_object('type' VALUE 'file', 'path' VALUE COALESCE(file_path, '')));
END;

CREATE FUNCTION pg_tde_change_key_provider_file(provider_name TEXT, file_path JSON)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_file_keyring_provider_options function.
    SELECT pg_tde_change_key_provider('file', provider_name,
                json_object('type' VALUE 'file', 'path' VALUE file_path));
END;

CREATE FUNCTION pg_tde_change_key_provider_vault_v2(provider_name TEXT,
                                                    vault_token TEXT,
                                                    vault_url TEXT,
                                                    vault_mount_path TEXT,
                                                    vault_ca_path TEXT)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_vaultV2_keyring_provider_options function.
    SELECT pg_tde_change_key_provider('vault-v2', provider_name,
                            json_object('type' VALUE 'vault-v2',
                            'url' VALUE COALESCE(vault_url, ''),
                            'token' VALUE COALESCE(vault_token, ''),
                            'mountPath' VALUE COALESCE(vault_mount_path, ''),
                            'caPath' VALUE COALESCE(vault_ca_path, '')));
END;

CREATE FUNCTION pg_tde_change_key_provider_vault_v2(provider_name TEXT,
                                                    vault_token JSON,
                                                    vault_url JSON,
                                                    vault_mount_path JSON,
                                                    vault_ca_path JSON)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_vaultV2_keyring_provider_options function.
    SELECT pg_tde_change_key_provider('vault-v2', provider_name,
                            json_object('type' VALUE 'vault-v2',
                            'url' VALUE vault_url,
                            'token' VALUE vault_token,
                            'mountPath' VALUE vault_mount_path,
                            'caPath' VALUE vault_ca_path));
END;

CREATE FUNCTION pg_tde_change_key_provider_kmip(provider_name TEXT,
                                                kmip_host TEXT,
                                                kmip_port INT,
                                                kmip_ca_path TEXT,
                                                kmip_cert_path TEXT)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_kmip_keyring_provider_options function.
    SELECT pg_tde_change_key_provider('kmip', provider_name,
                            json_object('type' VALUE 'kmip',
                            'host' VALUE COALESCE(kmip_host, ''),
                            'port' VALUE kmip_port,
                            'caPath' VALUE COALESCE(kmip_ca_path, ''),
                            'certPath' VALUE COALESCE(kmip_cert_path, '')));
END;

CREATE FUNCTION pg_tde_change_key_provider_kmip(provider_name TEXT,
                                                kmip_host JSON,
                                                kmip_port JSON,
                                                kmip_ca_path JSON,
                                                kmip_cert_path JSON)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_kmip_keyring_provider_options function.
    SELECT pg_tde_change_key_provider('kmip', provider_name,
                            json_object('type' VALUE 'kmip',
                            'host' VALUE kmip_host,
                            'port' VALUE kmip_port,
                            'caPath' VALUE kmip_ca_path,
                            'certPath' VALUE kmip_cert_path));
END;

-- Global Tablespace Key Provider Management
CREATE FUNCTION pg_tde_change_global_key_provider(provider_type TEXT, provider_name TEXT, options JSON)
RETURNS INT
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_change_global_key_provider_file(provider_name TEXT, file_path TEXT)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_file_keyring_provider_options function.
    SELECT pg_tde_change_global_key_provider('file', provider_name,
                json_object('type' VALUE 'file', 'path' VALUE COALESCE(file_path, '')));
END;

CREATE FUNCTION pg_tde_change_global_key_provider_file(provider_name TEXT, file_path JSON)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_file_keyring_provider_options function.
    SELECT pg_tde_change_global_key_provider('file', provider_name,
                json_object('type' VALUE 'file', 'path' VALUE file_path));
END;

CREATE FUNCTION pg_tde_change_global_key_provider_vault_v2(provider_name TEXT,
                                                           vault_token TEXT,
                                                           vault_url TEXT,
                                                           vault_mount_path TEXT,
                                                           vault_ca_path TEXT)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_vaultV2_keyring_provider_options function.
    SELECT pg_tde_change_global_key_provider('vault-v2', provider_name,
                            json_object('type' VALUE 'vault-v2',
                            'url' VALUE COALESCE(vault_url, ''),
                            'token' VALUE COALESCE(vault_token, ''),
                            'mountPath' VALUE COALESCE(vault_mount_path, ''),
                            'caPath' VALUE COALESCE(vault_ca_path, '')));
END;

CREATE FUNCTION pg_tde_change_global_key_provider_vault_v2(provider_name TEXT,
                                                           vault_token JSON,
                                                           vault_url JSON,
                                                           vault_mount_path JSON,
                                                           vault_ca_path JSON)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_vaultV2_keyring_provider_options function.
    SELECT pg_tde_change_global_key_provider('vault-v2', provider_name,
                            json_object('type' VALUE 'vault-v2',
                            'url' VALUE vault_url,
                            'token' VALUE vault_token,
                            'mountPath' VALUE vault_mount_path,
                            'caPath' VALUE vault_ca_path));
END;

CREATE FUNCTION pg_tde_change_global_key_provider_kmip(provider_name TEXT,
                                                       kmip_host TEXT,
                                                       kmip_port INT,
                                                       kmip_ca_path TEXT,
                                                       kmip_cert_path TEXT)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_kmip_keyring_provider_options function.
    SELECT pg_tde_change_global_key_provider('kmip', provider_name,
                            json_object('type' VALUE 'kmip',
                            'host' VALUE COALESCE(kmip_host, ''),
                            'port' VALUE kmip_port,
                            'caPath' VALUE COALESCE(kmip_ca_path, ''),
                            'certPath' VALUE COALESCE(kmip_cert_path, '')));
END;

CREATE FUNCTION pg_tde_change_global_key_provider_kmip(provider_name TEXT,
                                                       kmip_host JSON,
                                                       kmip_port JSON,
                                                       kmip_ca_path JSON,
                                                       kmip_cert_path JSON)
RETURNS INT
LANGUAGE SQL
BEGIN ATOMIC
    -- JSON keys in the options must be matched to the keys in
    -- load_kmip_keyring_provider_options function.
    SELECT pg_tde_change_global_key_provider('vault-v2', provider_name,
                            json_object('type' VALUE 'vault-v2',
                            'host' VALUE kmip_host,
                            'port' VALUE kmip_port,
                            'caPath' VALUE kmip_ca_path,
                            'certPath' VALUE kmip_cert_path));
END;


CREATE FUNCTION pg_tde_internal_refresh_sequences(table_oid OID)
RETURNS VOID
AS
$BODY$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
            SELECT s.relname AS sequence_name,
                ns.nspname AS sequence_namespace,
                se.seqstart AS sequence_start
            FROM pg_class AS t
            JOIN pg_attribute AS a
                ON a.attrelid = t.oid
            JOIN pg_depend AS d
                ON d.refobjid = t.oid
                AND d.refobjsubid = a.attnum
            JOIN pg_class AS s
                ON s.oid = d.objid
            JOIN pg_sequence AS se
                ON se.seqrelid = d.objid
            JOIN pg_namespace AS ns
                ON ns.oid = s.relnamespace
            WHERE d.classid = 'pg_catalog.pg_class'::regclass
            AND d.refclassid = 'pg_catalog.pg_class'::regclass
            AND d.deptype IN ('i', 'a')
            AND t.relkind IN ('r', 'P')
            AND s.relkind = 'S'
            AND t.oid = table_oid
    LOOP
        EXECUTE format('ALTER SEQUENCE %s.%s START %s', rec.sequence_namespace, rec.sequence_name, rec.sequence_start);
    END LOOP;
END
$BODY$
LANGUAGE plpgsql;

CREATE FUNCTION pg_tde_is_encrypted(relation regclass)
RETURNS boolean
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_set_principal_key(principal_key_name TEXT, provider_name TEXT DEFAULT NULL, ensure_new_key BOOLEAN DEFAULT FALSE)
RETURNS boolean
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_set_global_principal_key(principal_key_name TEXT, provider_name TEXT DEFAULT NULL, ensure_new_key BOOLEAN DEFAULT FALSE)
RETURNS boolean
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_set_server_principal_key(principal_key_name TEXT, provider_name TEXT DEFAULT NULL, ensure_new_key BOOLEAN DEFAULT FALSE)
RETURNS boolean
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_extension_initialize()
RETURNS VOID
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_verify_principal_key()
RETURNS VOID
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_verify_global_principal_key()
RETURNS VOID
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_principal_key_info()
RETURNS TABLE ( principal_key_name text,
                key_provider_name text,
                key_provider_id integer,
                key_createion_time timestamp with time zone)
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_global_principal_key_info()
RETURNS TABLE ( principal_key_name text,
                key_provider_name text,     
                key_provider_id integer,
                key_createion_time timestamp with time zone)
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_delete_global_key_provider(provider_name TEXT)
RETURNS VOID
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_delete_key_provider(provider_name TEXT)
RETURNS VOID
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_version() RETURNS TEXT LANGUAGE C AS 'MODULE_PATHNAME';

-- Table access method
CREATE FUNCTION pg_tdeam_handler(internal)
RETURNS table_am_handler
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE ACCESS METHOD tde_heap TYPE TABLE HANDLER pg_tdeam_handler;
COMMENT ON ACCESS METHOD tde_heap IS 'tde_heap table access method';

CREATE FUNCTION pg_tde_ddl_command_start_capture()
RETURNS event_trigger
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE FUNCTION pg_tde_ddl_command_end_capture()
RETURNS event_trigger
LANGUAGE C
AS 'MODULE_PATHNAME';

CREATE EVENT TRIGGER pg_tde_trigger_create_index
ON ddl_command_start
EXECUTE FUNCTION pg_tde_ddl_command_start_capture();
ALTER EVENT TRIGGER pg_tde_trigger_create_index ENABLE ALWAYS;

CREATE EVENT TRIGGER pg_tde_trigger_create_index_2
ON ddl_command_end
EXECUTE FUNCTION pg_tde_ddl_command_end_capture();
ALTER EVENT TRIGGER pg_tde_trigger_create_index_2 ENABLE ALWAYS;

-- Per database extension initialization
SELECT pg_tde_extension_initialize();

CREATE FUNCTION pg_tde_grant_global_key_management_to_role(
    target_role TEXT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = @extschema@
AS $$
BEGIN
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_add_global_key_provider(text, text, JSON) TO %I', target_role);

    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_add_global_key_provider_file(text, json) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_add_global_key_provider_file(text, text) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_add_global_key_provider_vault_v2(text, text, text, text, text) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_add_global_key_provider_vault_v2(text, JSON, JSON, JSON, JSON) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_add_global_key_provider_kmip(text, text, int, text, text) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_add_global_key_provider_kmip(text, JSON, JSON, JSON, JSON) TO %I', target_role);

    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_change_global_key_provider(text, text, JSON) TO %I', target_role);

    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_change_global_key_provider_file(text, json) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_change_global_key_provider_file(text, text) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_change_global_key_provider_vault_v2(text, text, text, text, text) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_change_global_key_provider_vault_v2(text, JSON, JSON, JSON, JSON) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_change_global_key_provider_kmip(text, text, int, text, text) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_change_global_key_provider_kmip(text, JSON, JSON, JSON, JSON) TO %I', target_role);

    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_delete_global_key_provider(text) TO %I', target_role);

    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_set_global_principal_key(text, text, BOOLEAN) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_set_server_principal_key(text, text, BOOLEAN) TO %I', target_role);

    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_set_default_principal_key(text, text, BOOLEAN) FROM %I', target_role);
END;
$$;

CREATE FUNCTION pg_tde_grant_local_key_management_to_role(
    target_role TEXT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = @extschema@
AS $$
BEGIN
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_add_key_provider(text, text, JSON) TO %I', target_role);

    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_add_key_provider_file(text, json) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_add_key_provider_file(text, text) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_add_key_provider_vault_v2(text, text, text, text, text) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_add_key_provider_vault_v2(text, JSON, JSON, JSON, JSON) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_add_key_provider_kmip(text, text, int, text, text) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_add_key_provider_kmip(text, JSON, JSON, JSON, JSON) TO %I', target_role);

    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_change_key_provider(text, text, JSON) TO %I', target_role);

    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_change_key_provider_file(text, json) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_change_key_provider_file(text, text) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_change_key_provider_vault_v2(text, text, text,text,text) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_change_key_provider_vault_v2(text, JSON, JSON,JSON,JSON) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_change_key_provider_kmip(text, text, int, text, text) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_change_key_provider_kmip(text, JSON, JSON, JSON, JSON) TO %I', target_role);

    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_delete_key_provider(text) TO %I', target_role);

    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_set_principal_key(text, text, BOOLEAN) TO %I', target_role);
END;
$$;

CREATE FUNCTION pg_tde_grant_key_viewer_to_role(
    target_role TEXT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = @extschema@
AS $$
BEGIN
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_list_all_key_providers() TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_list_all_global_key_providers() TO %I', target_role);

    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_principal_key_info() TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_global_principal_key_info() TO %I', target_role);
END;
$$;

CREATE FUNCTION pg_tde_revoke_global_key_management_from_role(
    target_role TEXT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = @extschema@
AS $$
BEGIN
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_add_global_key_provider(text, text, JSON) FROM %I', target_role);

    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_add_global_key_provider_file(text, json) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_add_global_key_provider_file(text, text) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_add_global_key_provider_vault_v2(text, text, text, text, text) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_add_global_key_provider_vault_v2(text, JSON, JSON, JSON, JSON) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_add_global_key_provider_kmip(text, text, int, text, text) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_add_global_key_provider_kmip(text, JSON, JSON, JSON, JSON) FROM %I', target_role);

    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_change_global_key_provider(text, text, JSON) FROM %I', target_role);

    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_change_global_key_provider_file(text, json) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_change_global_key_provider_file(text, text) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_change_global_key_provider_vault_v2(text, text, text, text, text) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_change_global_key_provider_vault_v2(text, JSON, JSON, JSON, JSON) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_change_global_key_provider_kmip(text, text, int, text, text) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_change_global_key_provider_kmip(text, JSON, JSON, JSON, JSON) FROM %I', target_role);

    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_delete_global_key_provider(text) FROM %I', target_role);

    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_set_global_principal_key(text, text, BOOLEAN) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_set_server_principal_key(text, text, BOOLEAN) FROM %I', target_role);

    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_set_default_principal_key(text, text, BOOLEAN) FROM %I', target_role);
END;
$$;

CREATE FUNCTION pg_tde_revoke_local_key_management_from_role(
    target_role TEXT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = @extschema@
AS $$
BEGIN
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_add_key_provider(text, text, JSON) FROM %I', target_role);

    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_add_key_provider_file(text, json) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_add_key_provider_file(text, text) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_add_key_provider_vault_v2(text, text, text, text, text) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_add_key_provider_vault_v2(text, JSON, JSON, JSON, JSON) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_add_key_provider_kmip(text, text, int, text, text) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_add_key_provider_kmip(text, JSON, JSON, JSON, JSON) FROM %I', target_role);

    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_change_key_provider(text, text, JSON) FROM %I', target_role);

    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_change_key_provider_file(text, json) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_change_key_provider_file(text, text) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_change_key_provider_vault_v2(text, text, text, text, text) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_change_key_provider_vault_v2(text, JSON, JSON, JSON, JSON) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_change_key_provider_kmip(text, text, int, text, text) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_change_key_provider_kmip(text, JSON, JSON, JSON, JSON) FROM %I', target_role);

    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_delete_key_provider(text) FROM %I', target_role);

    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_set_principal_key(text, text, BOOLEAN) FROM %I', target_role);
END;
$$;

CREATE FUNCTION pg_tde_revoke_key_viewer_from_role(
    target_role TEXT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = @extschema@
AS $$
BEGIN
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_list_all_key_providers() FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_list_all_global_key_providers() FROM %I', target_role);

    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_principal_key_info() FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_global_principal_key_info() FROM %I', target_role);
END;
$$;

CREATE FUNCTION pg_tde_grant_grant_management_to_role(
    target_role TEXT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = @extschema@
AS $$
BEGIN
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_grant_global_key_management_to_role(TEXT) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_grant_local_key_management_to_role(TEXT) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_grant_grant_management_to_role(TEXT) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_grant_key_viewer_to_role(TEXT) TO %I', target_role);

    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_revoke_global_key_management_from_role(TEXT) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_revoke_local_key_management_from_role(TEXT) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_revoke_grant_management_from_role(TEXT) TO %I', target_role);
    EXECUTE format('GRANT EXECUTE ON FUNCTION pg_tde_revoke_key_viewer_from_role(TEXT) TO %I', target_role);
END;
$$;

CREATE FUNCTION pg_tde_revoke_grant_management_from_role(
    target_role TEXT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = @extschema@
AS $$
BEGIN
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_grant_global_key_management_to_role(TEXT) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_grant_local_key_management_to_role(TEXT) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_grant_grant_management_to_role(TEXT) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_grant_key_viewer_to_role(TEXT) FROM %I', target_role);

    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_revoke_global_key_management_from_role(TEXT) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_revoke_local_key_management_from_role(TEXT) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_revoke_grant_management_from_role(TEXT) FROM %I', target_role);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION pg_tde_revoke_key_viewer_from_role(TEXT) FROM %I', target_role);
END;
$$;

-- Revoking all the privileges from the public role
SELECT pg_tde_revoke_local_key_management_from_role('public');
SELECT pg_tde_revoke_global_key_management_from_role('public');
SELECT pg_tde_revoke_grant_management_from_role('public');
SELECT pg_tde_revoke_key_viewer_from_role('public');
