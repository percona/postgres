# Copyright (c) 2026, PostgreSQL Global Development Group

# Encrypted WAL streams to a standby, is replayed there, and a promoted
# standby keeps encrypting.
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

my $primary = PostgreSQL::Test::Cluster->new('primary');
$primary->init(allows_streaming => 1);
$primary->append_conf('postgresql.conf',
	"shared_preload_libraries = 'test_xlog_crypt'\n");
$primary->start;
$primary->backup('bkp');

my $standby = PostgreSQL::Test::Cluster->new('standby');
$standby->init_from_backup($primary, 'bkp', has_streaming => 1);
$standby->start;

$primary->safe_psql('postgres', "CREATE TABLE t (v text)");
$primary->safe_psql('postgres',
	"INSERT INTO t VALUES ('CANARY_primary_61b0')");
$primary->wait_for_catchup($standby);
is($standby->safe_psql('postgres', "SELECT v FROM t"),
	'CANARY_primary_61b0', 'standby replayed encrypted WAL');
# The walreceiver stores the walsender's pages verbatim, so the standby's
# copy of the current segment is byte for byte the primary's up to the
# receive point, and the primary's copy is ciphertext.
my ($segname, $segoff) = split(/\|/,
	$primary->safe_psql('postgres',
		"SELECT * FROM pg_walfile_name_offset('"
		  . $standby->safe_psql('postgres', "SELECT pg_last_wal_receive_lsn()")
		  . "')"));
my $read_prefix = sub {
	my ($node) = @_;
	open(my $fh, '<:raw', $node->data_dir . "/pg_wal/$segname")
	  or die "open $segname: $!";
	my $buf;
	read($fh, $buf, $segoff) == $segoff or die "short read of $segname";
	close $fh;
	return $buf;
};
is(wal_contains($primary, 'CANARY_primary_61b0'), 0,
	'primary WAL is ciphertext');
ok(index($read_prefix->($standby), 'CANARY_primary_61b0') < 0,
	'received WAL is ciphertext on the standby');
is($read_prefix->($standby), $read_prefix->($primary),
	'standby holds the primary segment bytes verbatim');

$standby->promote;
$standby->safe_psql('postgres',
	"INSERT INTO t VALUES ('CANARY_promoted_2c8d')");
$standby->safe_psql('postgres', "SELECT pg_switch_wal()");
$standby->stop('immediate');
is(wal_contains($standby, 'CANARY_promoted_2c8d'),
	0, 'promoted standby encrypts its own WAL');
$standby->start;
is($standby->safe_psql('postgres', "SELECT count(*) FROM t"),
	'2', 'promoted standby recovers its own encrypted WAL');

$standby->stop;
$primary->stop;
done_testing();
