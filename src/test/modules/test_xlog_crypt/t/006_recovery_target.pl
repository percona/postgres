# Copyright (c) 2026, PostgreSQL Global Development Group

# A record that cannot be decrypted stops recovery only when replay gets to
# it, although the reader decodes records ahead of replay: a recovery target
# in front of the record is reached, and without a target the failure is
# still reported. A record that can be decrypted by then does not stop
# recovery at all.
use strict;
use warnings FATAL => 'all';
use PostgreSQL::Test::Cluster;
use PostgreSQL::Test::Utils;
use Test::More;

my $primary = PostgreSQL::Test::Cluster->new('primary');
$primary->init(has_archiving => 1, allows_streaming => 1);
$primary->append_conf('postgresql.conf',
	"shared_preload_libraries = 'test_xlog_crypt'\n");
$primary->start;
$primary->safe_psql('postgres', "CREATE TABLE t (v int)");
$primary->backup('base');

# A restore point, right behind it the record the restored nodes will not be
# able to decrypt, and more WAL behind that, with a second such record that
# spans pages.
$primary->safe_psql('postgres',
	"INSERT INTO t SELECT generate_series(1, 1000)");
$primary->safe_psql('postgres',
	"SELECT pg_create_restore_point('before_bad')");
$primary->safe_psql('postgres',
	"SELECT pg_logical_emit_message(false, 'crypt', 'not for the restored node')");
$primary->safe_psql('postgres',
	"INSERT INTO t SELECT generate_series(1001, 2000)");
$primary->safe_psql('postgres',
	"SELECT pg_logical_emit_message(false, 'crypt', repeat('x', 30000))");
$primary->safe_psql('postgres',
	"INSERT INTO t SELECT generate_series(2001, 3000)");
my $wal_block_size = $primary->safe_psql('postgres',
	"SELECT setting FROM pg_settings WHERE name = 'wal_block_size'");
my $rmid = $primary->safe_psql('postgres',
	"SELECT rm_id FROM pg_get_wal_resource_managers() WHERE rm_name = 'LogicalMessage'");
my $walfile = $primary->safe_psql('postgres',
	"SELECT pg_walfile_name(pg_current_wal_lsn())");
$primary->safe_psql('postgres', "SELECT pg_switch_wal()");
$primary->poll_query_until('postgres',
	"SELECT last_archived_wal >= '$walfile' FROM pg_stat_archiver")
  or die "timed out waiting for the archiver";

# The target is reached, the record behind it does not get in the way. The
# restored nodes do not archive: the timeline of one must not show up in the
# recovery of the other.
my $restored = PostgreSQL::Test::Cluster->new('restored');
$restored->init_from_backup($primary, 'base',
	has_restoring => 1, standby => 0);
$restored->append_conf('postgresql.conf',
	"test_xlog_crypt.fail_decrypt_rmgr = $rmid\n"
	  . "archive_mode = off\n"
	  . "recovery_target_name = 'before_bad'\n"
	  . "recovery_target_action = 'promote'\n");
my $ret = $restored->start(fail_ok => 1);
is($ret, 1, 'recovery reaches a target in front of an undecryptable record');
if ($ret)
{
	$restored->poll_query_until('postgres', "SELECT NOT pg_is_in_recovery()")
	  or die "timed out waiting for the end of recovery";
	is($restored->safe_psql('postgres', "SELECT count(*) FROM t"),
		'1000', 'records in front of the target replayed');
	$restored->stop;
}

# Without a target recovery gets to the record and fails there. It must not
# take the record for the end of WAL.
my $stuck = PostgreSQL::Test::Cluster->new('stuck');
$stuck->init_from_backup($primary, 'base', has_restoring => 1, standby => 0);
$stuck->append_conf('postgresql.conf',
	"test_xlog_crypt.fail_decrypt_rmgr = $rmid\n" . "archive_mode = off\n");
$ret = $stuck->start(fail_ok => 1);
is($ret, 0, 'recovery fails at the undecryptable record');
ok($stuck->log_contains('could not decrypt WAL record at'),
	'decrypt failure reported');
$stuck->stop if $ret;

# Decrypt fails as long as the record is only read ahead, and works once
# replay has reached it: nothing is lost, behind the records either.
my $late = PostgreSQL::Test::Cluster->new('late');
$late->init_from_backup($primary, 'base', has_restoring => 1, standby => 0);
$late->append_conf('postgresql.conf',
	"test_xlog_crypt.late_key_rmgr = $rmid\n" . "archive_mode = off\n");
$late->start;
$late->poll_query_until('postgres', "SELECT NOT pg_is_in_recovery()")
  or die "timed out waiting for the end of recovery";
is($late->safe_psql('postgres', "SELECT count(*) FROM t"),
	'3000', 'recovery continues behind records decrypted on the second try');
SKIP:
{
	skip "no read-ahead without recovery prefetch", 2
	  unless check_pg_config("#define HAVE_DECL_POSIX_FADVISE 1");

	my $log = slurp_file($late->logfile);
	my %found =
	  map { $_ => 1 } $log =~ /key found for record of length (\d+)/g;
	my @lens =
	  grep { $found{$_} } $log =~ /no key yet for record of length (\d+)/g;
	ok(scalar(grep { $_ < $wal_block_size } @lens),
		'small record decrypted on the second try');
	ok(scalar(grep { $_ > $wal_block_size } @lens),
		'record spanning pages decrypted on the second try');
}
$late->stop;

$primary->stop;
done_testing();
