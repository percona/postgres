#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use PostgreSQL::Test::Cluster;
use PostgreSQL::Test::Utils;
use Test::More;

use FindBin;
use lib $FindBin::RealBin;

use pgtde;

my $node = PostgreSQL::Test::Cluster->new('main');
$node->init;
$node->append_conf('postgresql.conf', "shared_preload_libraries = 'pg_tde'");
$node->start;

PGTDE::do_psql($node, 'postgres', q{CREATE EXTENSION IF NOT EXISTS pg_tde});
PGTDE::do_psql(
	$node, 'postgres', q{
		SELECT pg_tde_add_database_key_provider_file(
			provider_name => 'file-vault',
			file_path => '/tmp/pg_tde_test_keyring.per'
		)
	}
);
PGTDE::do_psql(
	$node, 'postgres', q{
		SELECT pg_tde_set_key_using_database_key_provider(
			key_name => 'test-db-key',
			provider_name => 'file-vault'
		)
	}
);
PGTDE::do_psql(
	$node, 'postgres', q{
		CREATE TABLE test_enc(
			id SERIAL,
			k VARCHAR(32),
			PRIMARY KEY (id)
		) USING tde_heap
	}
);
PGTDE::do_psql(
	$node, 'postgres', q{
		INSERT INTO test_enc (k) VALUES ('foobar'), ('barfoo')
	}
);

$node->restart;

is( PGTDE::do_psql(
		$node, 'postgres', q{
			SELECT * FROM test_enc ORDER BY id ASC
		}
	),
	"1|foobar\n2|barfoo",
	'tde_heap table can be read after server restart');

my $tablefile =
  $node->data_dir . '/'
  . PGTDE::do_psql($node, 'postgres',
	q{SELECT pg_relation_filepath('test_enc')});
my $tablefilecontents = slurp_file($tablefile);

unlike($tablefilecontents, qr/foo/,
	'table file does not contain plaintext data');

$node->stop;

done_testing();
