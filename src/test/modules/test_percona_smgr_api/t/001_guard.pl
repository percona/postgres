# Copyright (c) 2026, Percona LLC and/or its affiliates

# Test the guard on the upstream signatures of smgrcreate,
# RelationCreateStorage and index_create. test_old_smgr_api uses them like a
# third party extension built against upstream headers would.
# test_new_smgr_api disables them like pg_tde does. Without it they have to
# work, with it they have to fail before creating any storage.

use strict;
use warnings FATAL => 'all';

use PostgreSQL::Test::Cluster;
use PostgreSQL::Test::Utils;
use Test::More;

my $node = PostgreSQL::Test::Cluster->new('main');
$node->init;
$node->start;

$node->safe_psql('postgres', 'CREATE EXTENSION test_old_smgr_api');

my $dbdir = $node->data_dir . '/base/'
  . $node->safe_psql('postgres',
	"SELECT oid FROM pg_database WHERE datname = 'postgres'");

# Main forks of dropped relations stay as empty files until the next
# checkpoint, so checkpoint before listing.
sub relfiles
{
	$node->safe_psql('postgres', 'CHECKPOINT');
	opendir(my $dh, $dbdir) or die "could not open $dbdir: $!";
	my @files = sort grep { /^\d+/ } readdir($dh);
	closedir($dh);
	return join(',', @files);
}

sub fork_exists
{
	my ($rel, $fork) = @_;
	my $path = $node->safe_psql('postgres',
		"SELECT pg_relation_filepath('$rel')");
	return -e $node->data_dir . "/${path}_$fork";
}

sub expect_guard_error
{
	my ($sql, $func, $name) = @_;
	my ($ret, $stdout, $stderr) =
	  $node->psql('postgres', "$sql;\nSELECT 'alive'", on_error_stop => 0);
	like(
		$stderr,
		qr/ERROR:  An extension is trying to use the traditional $func method/,
		"$name: fails with guard error");
	is($stdout, 'alive', "$name: session usable after error");
}

# Upstream API works without the guard.

$node->safe_psql(
	'postgres', q{
CREATE TABLE t1 (a int) USING old_api_heap;
INSERT INTO t1 SELECT generate_series(1, 100);
CREATE UNLOGGED TABLE u1 (a int) USING old_api_heap;
CREATE TABLE h1 (a int);
INSERT INTO h1 SELECT generate_series(1, 100);
});
is($node->safe_psql('postgres', 'SELECT count(*) FROM t1'),
	'100', 'table using old API created');
ok(fork_exists('u1', 'init'), 'init fork created with old smgrcreate');

$node->safe_psql('postgres',
	'TRUNCATE t1; INSERT INTO t1 SELECT generate_series(1, 50)');
is($node->safe_psql('postgres', 'SELECT count(*) FROM t1'),
	'50', 'table using old API truncated');

ok(!fork_exists('h1', 'vm'), 'vm fork missing before old smgrcreate');
$node->safe_psql('postgres', "SELECT old_api_smgrcreate('h1', 'vm')");
ok(fork_exists('h1', 'vm'), 'vm fork created with old smgrcreate');

$node->safe_psql('postgres',
	"SELECT old_api_index_create('h1', 'h1_a_idx', 'a')");
is( $node->safe_psql(
		'postgres', q{
SET enable_seqscan = off;
SET enable_bitmapscan = off;
SELECT a FROM h1 WHERE a = 42;
}),
	'42',
	'index created with old index_create is usable');

# Upstream API fails with the guard.

$node->append_conf('postgresql.conf',
	"shared_preload_libraries = 'test_new_smgr_api'");
$node->restart;

$node->safe_psql('postgres', 'CREATE TABLE h2 (a int)');

my $files_before = relfiles();

expect_guard_error('CREATE TABLE t2 (a int) USING old_api_heap',
	'RelationCreateStorage', 'create table');
expect_guard_error('CREATE UNLOGGED TABLE u2 (a int) USING old_api_heap',
	'RelationCreateStorage', 'create unlogged table');
expect_guard_error('TRUNCATE t1', 'RelationCreateStorage', 'truncate');
expect_guard_error(
	'BEGIN; CREATE TABLE t3 (a int); TRUNCATE t3; '
	  . 'CREATE TABLE t4 (a int) USING old_api_heap; COMMIT',
	'RelationCreateStorage',
	'create table in transaction block');
expect_guard_error("SELECT old_api_smgrcreate('h2', 'vm')",
	'smgrcreate', 'smgrcreate');
expect_guard_error("SELECT old_api_index_create('h2', 'h2_a_idx', 'a')",
	'index_create', 'index_create');

is(relfiles(), $files_before, 'no files created by failed statements');
ok(!fork_exists('h2', 'vm'), 'vm fork not created');
is( $node->safe_psql(
		'postgres',
		"SELECT count(*) FROM pg_class WHERE relname IN ('t2', 'u2', 't3', 't4', 'h2_a_idx')"
	),
	'0',
	'no catalog entries left by failed statements');

# Existing storage stays usable, only new storage creation is blocked.
$node->safe_psql('postgres', 'INSERT INTO t1 VALUES (51)');
is($node->safe_psql('postgres', 'SELECT count(*) FROM t1'),
	'51', 'existing table using old API still readable and writable');

# The new API used by core is not affected.
$node->safe_psql(
	'postgres', q{
CREATE TABLE h3 (a int);
INSERT INTO h3 SELECT generate_series(1, 10);
CREATE INDEX ON h3 (a);
TRUNCATE h3;
});
pass('core storage creation works with guard');

$node->stop('immediate');
$node->start;
is($node->safe_psql('postgres', 'SELECT count(*) FROM t1'),
	'51', 'crash recovery after failed statements');

# Load order does not matter.

foreach my $libs ('test_old_smgr_api,test_new_smgr_api',
	'test_new_smgr_api,test_old_smgr_api')
{
	$node->append_conf('postgresql.conf',
		"shared_preload_libraries = '$libs'");
	$node->restart;
	expect_guard_error('CREATE TABLE t5 (a int) USING old_api_heap',
		'RelationCreateStorage', "preload order $libs");
}

# Guard is gone after removing the library.

$node->append_conf('postgresql.conf', "shared_preload_libraries = ''");
$node->restart;
$node->safe_psql('postgres', 'CREATE TABLE t6 (a int) USING old_api_heap');
pass('old API works again without guard');

done_testing();
