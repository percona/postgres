# Copyright (c) 2026, PostgreSQL Global Development Group

# Frontend tools without a hook: pg_waldump shows opaque records and
# --stats still works, pg_rewind refuses.
use strict;
use warnings FATAL => 'all';
use IPC::Run;
use PostgreSQL::Test::Cluster;
use PostgreSQL::Test::Utils;
use Test::More;

my $primary = PostgreSQL::Test::Cluster->new('primary');
$primary->init(allows_streaming => 1);
$primary->append_conf('postgresql.conf',
	"shared_preload_libraries = 'test_xlog_crypt'\n"
	  . "wal_log_hints = on\n");
$primary->start;
$primary->backup('bkp');

my $standby = PostgreSQL::Test::Cluster->new('standby');
$standby->init_from_backup($primary, 'bkp', has_streaming => 1);
$standby->start;

$primary->safe_psql('postgres', "CREATE TABLE t (v text)");
$primary->safe_psql('postgres', "INSERT INTO t VALUES ('x')");
$primary->wait_for_catchup($standby);

my $seg = $primary->safe_psql('postgres',
	"SELECT pg_walfile_name(pg_current_wal_insert_lsn())");
$primary->safe_psql('postgres', "SELECT pg_switch_wal()");
my $waldir = $primary->data_dir . '/pg_wal';

my ($out, $err);

# The segment was switched out, so the reader stops cleanly at XLOG_SWITCH
# and pg_waldump exits 0.
ok( IPC::Run::run(
		[ 'pg_waldump', '-p', $waldir, $seg ],
		'>', \$out, '2>', \$err),
	'pg_waldump exits 0 on encrypted WAL');
note("pg_waldump stderr: $err") if length $err;
like(
	$out,
	qr/rmgr: Heap .*desc: ENCRYPTED \(\d+ body bytes, cannot decrypt\)/,
	'heap record shown as opaque');
unlike($out, qr/rmgr: Heap [^\n]*desc: (?!ENCRYPTED)/,
	'every heap record is opaque');
ok( IPC::Run::run(
		[ 'pg_waldump', '--stats', '-p', $waldir, $seg ],
		'>', \$out, '2>', \$err),
	'pg_waldump --stats exits 0');
like($out, qr/^Heap\s+[1-9]/m, 'stats count heap records');
like(
	$err,
	qr/full-page images in \d+ encrypted records are counted as record data/,
	'stats report opaque records');
ok( IPC::Run::run(
		[ 'pg_waldump', '--fullpage', '-p', $waldir, $seg ],
		'>', \$out, '2>', \$err),
	'pg_waldump --fullpage exits 0');
like($err, qr/skipped \d+ encrypted records that cannot be matched/,
	'filtered opaque records are reported');
unlike($err, qr/full-page images in/,
	'no other warning for filtered records');
my $fpw_dir = PostgreSQL::Test::Utils::tempdir();
ok( IPC::Run::run(
		[ 'pg_waldump', '--save-fullpage', $fpw_dir, '-p', $waldir, $seg ],
		'>', \$out, '2>', \$err),
	'pg_waldump --save-fullpage exits 0');
like(
	$err,
	qr/full-page images in \d+ encrypted records were not saved/,
	'unsaved full-page images are reported');

# Diverge: promote the standby, write on both, then try to rewind the old
# primary. The encrypted shutdown checkpoint makes readOneRecord the call
# site that fires.
$standby->promote;
# pg_rewind compares control file timelines; promote returns before the
# end-of-recovery checkpoint has advanced the source's.
$standby->safe_psql('postgres', 'CHECKPOINT');
$standby->safe_psql('postgres', "INSERT INTO t VALUES ('standby')");
$primary->safe_psql('postgres', "INSERT INTO t VALUES ('primary')");
$primary->stop;

my $ret = IPC::Run::run(
	[
		'pg_rewind',
		'--source-server', $standby->connstr('postgres'),
		'--target-pgdata', $primary->data_dir
	],
	'>', \$out, '2>', \$err);
ok(!$ret, 'pg_rewind fails on encrypted WAL');
like($err, qr/is encrypted and pg_rewind cannot decrypt it/,
	'pg_rewind names the reason');

$standby->stop;
done_testing();
