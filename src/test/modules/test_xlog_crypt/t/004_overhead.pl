# Copyright (c) 2026, PostgreSQL Global Development Group

# Prefixes and suffixes of several lengths round-trip, records of any length
# survive page boundaries, the reader takes the
# overhead from the record rather than the setting, the checkpoint record is
# read twice during recovery, and pg_walinspect decodes the encrypted range.
use strict;
use warnings FATAL => 'all';
use PostgreSQL::Test::Cluster;
use PostgreSQL::Test::Utils;
use Test::More;

sub wal_contains
{
	my ($node, $needle) = @_;
	opendir(my $dh, $node->data_dir . '/pg_wal') or die "opendir pg_wal: $!";
	for my $f (grep { /^[0-9A-F]{24}$/ } readdir $dh)
	{
		open(my $fh, '<:raw', $node->data_dir . "/pg_wal/$f")
		  or die "open $f: $!";
		local $/;
		my $data = <$fh>;
		close $fh;
		if (index($data, $needle) >= 0)
		{
			closedir $dh;
			return 1;
		}
	}
	closedir $dh;
	return 0;
}

for my $case ([ 1, 0 ], [ 64, 64 ], [ 5, 1 ], [ 2, 7 ])
{
	my ($overhead, $suffix) = @$case;
	my $name = "prefix $overhead suffix $suffix";
	my $canary = "CANARY_overhead_${overhead}_${suffix}_a91c";
	my $node = PostgreSQL::Test::Cluster->new("ovh${overhead}_$suffix");
	$node->init;
	$node->append_conf('postgresql.conf',
		"shared_preload_libraries = 'test_xlog_crypt'\n"
		  . "test_xlog_crypt.overhead = $overhead\n"
		  . "test_xlog_crypt.suffix = $suffix\n");
	$node->start;
	$node->safe_psql('postgres', "CREATE TABLE t (v text)");
	$node->safe_psql('postgres', "INSERT INTO t VALUES ('$canary')");
	$node->safe_psql('postgres', "SELECT pg_switch_wal()");
	$node->stop('immediate');
	is(wal_contains($node, $canary), 0, "$name: canary absent from WAL");
	$node->start;
	is($node->safe_psql('postgres',
			"SELECT count(*) FROM t WHERE v = '$canary'"),
		'1', "$name: row recovered");
	$node->stop;
}

# Records of every length up to a bit more than a page, so that prefix,
# suffix and CRC each get cut by a page boundary in some of them.
my $lengths = PostgreSQL::Test::Cluster->new('lengths');
$lengths->init;
$lengths->append_conf('postgresql.conf',
	"shared_preload_libraries = 'test_xlog_crypt'\n"
	  . "test_xlog_crypt.overhead = 13\n"
	  . "test_xlog_crypt.suffix = 9\n");
$lengths->start;
$lengths->safe_psql('postgres', "CREATE EXTENSION pg_walinspect");
my $lstart = $lengths->safe_psql('postgres', "SELECT pg_current_wal_lsn()");
$lengths->safe_psql('postgres',
	"SELECT count(pg_logical_emit_message(false, 'len', repeat('LENCANARY', 1 + g / 9)::bytea || repeat('x', g % 9)::bytea)) "
	  . "FROM generate_series(1, 9000, 5) g");
my $lend = $lengths->safe_psql('postgres',
	"SELECT pg_logical_emit_message(false, 'len', 'end', true)");
$lengths->stop('immediate');
is(wal_contains($lengths, 'LENCANARY'), 0,
	'records of all lengths: body absent from WAL');
$lengths->start;
is( $lengths->safe_psql(
		'postgres',
		"SELECT count(*) FROM pg_get_wal_records_info('$lstart', '$lend') "
		  . "WHERE resource_manager = 'LogicalMessage'"),
	'1801',
	'records of all lengths: all decrypted');
$lengths->stop;

# WAL written with one overhead is replayed under another: the reader has
# to take the overhead from each record.
my $node = PostgreSQL::Test::Cluster->new('switch');
$node->init;
$node->append_conf('postgresql.conf',
	"shared_preload_libraries = 'test_xlog_crypt'\n"
	  . "test_xlog_crypt.overhead = 5\n");
$node->start;
$node->safe_psql('postgres', "CREATE TABLE t (v text)");
$node->safe_psql('postgres', "INSERT INTO t VALUES ('written under 5')");
$node->stop('immediate');
$node->adjust_conf('postgresql.conf', 'test_xlog_crypt.overhead', '1');
$node->start;
is($node->safe_psql('postgres', "SELECT count(*) FROM t"), '1',
	'WAL written under overhead 5 replayed under overhead 1');
$node->safe_psql('postgres', "INSERT INTO t VALUES ('written under 1')");
$node->stop('immediate');
$node->start;
is($node->safe_psql('postgres', "SELECT count(*) FROM t"), '2',
	'mixed-overhead WAL replayed');

# Crash recovery reads the (encrypted) checkpoint record twice: once to find
# the redo point, once while replaying from it.
$node->safe_psql('postgres', "CHECKPOINT");
$node->safe_psql('postgres', "INSERT INTO t VALUES ('after encrypted checkpoint')");
$node->stop('immediate');
$node->start;
is($node->safe_psql('postgres', "SELECT count(*) FROM t"), '3',
	'recovery through an encrypted checkpoint record');

$node->safe_psql('postgres', "CREATE EXTENSION pg_walinspect");
my $start = $node->safe_psql('postgres', "SELECT pg_current_wal_lsn()");
$node->safe_psql('postgres',
	"INSERT INTO t SELECT 'walinspect_' || g FROM generate_series(1, 2000) g");
my $end = $node->safe_psql('postgres', "SELECT pg_current_wal_lsn()");
# pg_walinspect reads the first record twice from the same page cache
# (XLogFindNextRecord, then XLogBeginRead), so a decrypt that leaked
# plaintext into the page cache would fail the CRC here. Check content, not
# just that the call returns.
my $inserts = $node->safe_psql('postgres',
	"SELECT count(*) FROM pg_get_wal_records_info('$start', '$end') "
	  . "WHERE resource_manager = 'Heap' AND record_type LIKE 'INSERT%'");
is($inserts, '2000', 'pg_walinspect decoded every encrypted heap insert');

$node->stop;
done_testing();
