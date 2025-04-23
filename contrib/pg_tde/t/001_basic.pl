#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use PostgreSQL::Test::Cluster;
use PostgreSQL::Test::Utils;
use Test::More;


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

is($node->safe_psql('postgres', q{SELECT * FROM test_enc ORDER BY id ASC}),
	"1|foobar\n2|barfoo", 'tde_heap table can be read after server restart');

my $tablefile = $node->data_dir . '/'
  . $node->safe_psql('postgres', q{SELECT pg_relation_filepath('test_enc')});
my $tablefilecontents = slurp_file($tablefile);

unlike($tablefilecontents, qr/foo/,
	'table file does not contain plaintext data');

$node->stop;

done_testing();
