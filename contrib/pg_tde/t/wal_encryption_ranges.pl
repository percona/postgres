#!/usr/bin/perl

use strict;
use warnings;
use File::Basename;
use Test::More;
use lib 't';
use pgtde;

PGTDE::setup_files_dir(basename($0));

unlink('/tmp/wal_encryption_ranges.per');

my $psql_out = '';

my $node = PostgreSQL::Test::Cluster->new('main');
$node->init;
$node->append_conf('postgresql.conf', "shared_preload_libraries = 'pg_tde'");
$node->append_conf('postgresql.conf', "wal_level = 'logical'");
$node->start;

# Create and configure pg_tde extension
$node->psql('postgres', "CREATE EXTENSION pg_tde;");

$node->psql('postgres',
	"SELECT pg_tde_add_global_key_provider_file('file-keyring', '/tmp/wal_encryption_ranges.per');"
);

$node->psql('postgres',
	"SELECT pg_tde_create_key_using_global_key_provider('server-key', 'file-keyring');"
);
$node->psql('postgres',
	"SELECT pg_tde_set_server_key_using_global_key_provider('server-key', 'file-keyring');"
);

$node->psql('postgres', 'SELECT pg_tde_verify_server_key();');

# Create test table and enable WAL encryption
$node->psql('postgres',
	'CREATE TABLE test_wal (id SERIAL, k INTEGER, PRIMARY KEY (id));');

$node->psql('postgres', 'ALTER SYSTEM SET pg_tde.wal_encrypt = on;');

$node->restart;

# Insert some data to generate WAL records and check that WAL records are encrypted
$node->psql('postgres', 'INSERT INTO test_wal (k) VALUES (1), (2);');

my $enc_lsn = $node->safe_psql('postgres', "SELECT pg_current_wal_lsn();");
$node->psql(
	'postgres',
	"SELECT pg_tde_is_wal_record_encrypted('$enc_lsn'::pg_lsn);",
	stdout => \$psql_out);
is($psql_out, 't', "Check that WAL record is encrypted");

# Force PG to switch to a new WAL segment to avoid situation when we decrypt
# non-full WAL page on WAL encryption off.
$node->psql('postgres', 'SELECT pg_switch_wal();');
$node->psql('postgres', 'ALTER SYSTEM SET pg_tde.wal_encrypt = off;');

$node->restart;

# Insert more data to generate WAL records and check that they are not encrypted
$node->psql('postgres', 'INSERT INTO test_wal (k) VALUES (3), (4);');

my $dec_lsn = $node->safe_psql('postgres', "SELECT pg_current_wal_lsn();");
$node->psql(
	'postgres',
	"SELECT pg_tde_is_wal_record_encrypted('$dec_lsn'::pg_lsn);",
	stdout => \$psql_out);
is($psql_out, 'f', "Check that WAL record is not encrypted");

# Check that previously encrypted record is still encrypted
$node->psql(
	'postgres',
	"SELECT pg_tde_is_wal_record_encrypted('$enc_lsn'::pg_lsn);",
	stdout => \$psql_out);
is($psql_out, 't', "Check that WAL record is still encrypted");

# Check that WAL records that we recorded before match the encryption ranges. We use
# relative comparisons to avoid issues with LSN stability across different runs of the test.
my $ranges_count = $node->safe_psql(
	'postgres', "SELECT count(*) FROM pg_tde_get_wal_encryption_ranges()
            WHERE start_lsn <= '$enc_lsn'::pg_lsn
            AND end_lsn > '$enc_lsn'::pg_lsn
            AND end_lsn <= '$dec_lsn'::pg_lsn
            AND start_tli = 1
            AND end_tli = 1;");
is($ranges_count, 1,
	"Check that WAL records correspond to expected encryption range");

$node->psql('postgres', 'DROP EXTENSION pg_tde;');
$node->stop;

done_testing();
