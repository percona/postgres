# Copyright (c) 2026, PostgreSQL Global Development Group

# A decrypt failure stops recovery instead of ending WAL there, and the
# XLOG rmgr opt-out leaves the checkpoint readable without a hook.
use strict;
use warnings FATAL => 'all';
use IPC::Run;
use PostgreSQL::Test::Cluster;
use PostgreSQL::Test::Utils;
use Test::More;

my $node = PostgreSQL::Test::Cluster->new('main');
$node->init;
$node->append_conf('postgresql.conf',
	"shared_preload_libraries = 'test_xlog_crypt'\n"
	  . "test_xlog_crypt.xlog_rmgr_plaintext = on\n");
$node->start;

$node->safe_psql('postgres', "CREATE TABLE t (v text)");
$node->safe_psql('postgres', "CHECKPOINT");
$node->safe_psql('postgres', "INSERT INTO t VALUES ('after checkpoint')");
my $seg = $node->safe_psql('postgres',
	"SELECT pg_walfile_name(pg_current_wal_insert_lsn())");
$node->stop('immediate');

# The checkpoint record is plaintext (opt-out), so recovery can start; the
# first encrypted record after it fails to decrypt and the startup process
# exits.
$node->append_conf('postgresql.conf', "test_xlog_crypt.fail_decrypt = on\n");
my $log_offset = -s $node->logfile;
my $ret = $node->start(fail_ok => 1);
is($ret, 0, 'start fails on a decrypt failure');
ok($node->log_contains('could not decrypt WAL record at', $log_offset),
	'decrypt failure reported');

# pg_waldump without a hook: the checkpoint decodes, heap records are opaque.
my ($out, $err);
IPC::Run::run([ 'pg_waldump', '-p', $node->data_dir . '/pg_wal', $seg ],
	'>', \$out, '2>', \$err);
note("pg_waldump stderr: $err") if length $err;
like($out, qr/rmgr: XLOG .*desc: CHECKPOINT_ONLINE/,
	'opted-out XLOG record decoded without a hook');
like($out, qr/rmgr: Heap .*desc: ENCRYPTED \(\d+ body bytes, cannot decrypt\)/,
	'heap record shown as opaque');

# Nothing was lost: with decryption working again recovery replays the row.
$node->adjust_conf('postgresql.conf', 'test_xlog_crypt.fail_decrypt', 'off');
$node->start;
is($node->safe_psql('postgres', "SELECT count(*) FROM t"),
	'1', 'records after the failure are replayed once decryption works');

$node->stop;
done_testing();
