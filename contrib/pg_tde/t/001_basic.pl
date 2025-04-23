#!/usr/bin/perl

use strict;
use warnings;
use File::Basename;
use Test::More;
use lib 't';
use pgtde;

PGTDE::setup_files_dir(basename($0));

my $node = PostgreSQL::Test::Cluster->new('main');
$node->init;
$node->append_conf('postgresql.conf', "shared_preload_libraries = 'pg_tde'");
$node->start;

$node->safe_psql('postgres', q{CREATE EXTENSION IF NOT EXISTS pg_tde});
$node->safe_psql('postgres',
	q{SELECT pg_tde_add_database_key_provider_file('file-vault','/tmp/pg_tde_test_keyring.per')}
);
$node->safe_psql('postgres',
	q{SELECT pg_tde_set_key_using_database_key_provider('test-db-key','file-vault')}
);
$node->safe_psql('postgres',
	q{CREATE TABLE test_enc(id SERIAL,k VARCHAR(32),PRIMARY KEY (id)) USING tde_heap}
);
$node->safe_psql('postgres',
	q{INSERT INTO test_enc (k) VALUES ('foobar'),('barfoo')});

$node->restart;

PGTDE::psql($node, 'postgres', 'SELECT * FROM test_enc ORDER BY id ASC;');

# Verify that we can't see the data in the file
my $tablefile = $node->safe_psql('postgres', 'SHOW data_directory;');
$tablefile .= '/';
$tablefile .=
  $node->safe_psql('postgres', 'SELECT pg_relation_filepath(\'test_enc\');');

my $strings = 'TABLEFILE FOUND: ';
$strings .= `(ls  $tablefile >/dev/null && echo yes) || echo no`;
PGTDE::append_to_result_file($strings);

$strings = 'CONTAINS FOO (should be empty): ';
$strings .= `strings $tablefile | grep foo`;
PGTDE::append_to_result_file($strings);

$node->stop;

# Compare the expected and out file
my $compare = PGTDE->compare_results();

is($compare, 0,
	"Compare Files: $PGTDE::expected_filename_with_path and $PGTDE::out_filename_with_path files."
);

done_testing();
