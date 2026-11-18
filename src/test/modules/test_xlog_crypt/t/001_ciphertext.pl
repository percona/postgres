# Copyright (c) 2026, PostgreSQL Global Development Group

# WAL on disk is ciphertext and crash recovery decrypts it.
use strict;
use warnings FATAL => 'all';
use PostgreSQL::Test::Cluster;
use PostgreSQL::Test::Utils;
use Test::More;

my $canary = 'CANARY_xlog_crypt_7f3a9c2e_must_not_appear_on_disk';

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

my $node = PostgreSQL::Test::Cluster->new('main');
$node->init;
$node->append_conf('postgresql.conf',
	"shared_preload_libraries = 'test_xlog_crypt'\n");
$node->start;

$node->safe_psql('postgres', "CREATE TABLE t (v text)");
$node->safe_psql('postgres', "INSERT INTO t VALUES ('$canary')");
$node->safe_psql('postgres', "SELECT pg_switch_wal()");
$node->stop('immediate');

is(wal_contains($node, $canary), 0, 'canary absent from WAL segments');

# Positive control for the scanner: with the hook disabled the canary is
# found, so a silent empty scan cannot make the assertions above pass.
my $plain = PostgreSQL::Test::Cluster->new('plain');
$plain->init;
$plain->append_conf('postgresql.conf',
	"shared_preload_libraries = 'test_xlog_crypt'\n"
	  . "test_xlog_crypt.enabled = off\n");
$plain->start;
$plain->safe_psql('postgres', "CREATE TABLE t (v text)");
$plain->safe_psql('postgres', "INSERT INTO t VALUES ('$canary')");
$plain->safe_psql('postgres', "SELECT pg_switch_wal()");
$plain->stop;
is(wal_contains($plain, $canary), 1, 'scanner finds the canary in plaintext WAL');

$node->start;
is($node->safe_psql('postgres', "SELECT count(*) FROM t WHERE v = '$canary'"),
	'1', 'row recovered from encrypted WAL');

# A record much larger than a page: a logical message is written as one
# record and never compressed, unlike a toasted tuple.
$node->safe_psql('postgres',
	"SELECT pg_logical_emit_message(true, 'crypt', repeat('BIGCANARY_c0ffee_', 20000))");
$node->safe_psql('postgres', "INSERT INTO t VALUES ('after big record')");
$node->safe_psql('postgres', "SELECT pg_switch_wal()");
$node->stop('immediate');
is(wal_contains($node, 'BIGCANARY_c0ffee_'), 0,
	'multi-page record body absent from WAL segments');
$node->start;
is($node->safe_psql('postgres', "SELECT count(*) FROM t"), '2',
	'records after the multi-page record recovered');

# The hook can tell which relation a record changes: the rows of a table
# opted out by its relfilenode are in the WAL as they are, those of another
# table are not.
$node->safe_psql('postgres', "CREATE TABLE plain_t (v text)");
my $relnode = $node->safe_psql('postgres',
	"SELECT pg_relation_filenode('plain_t')");
$node->append_conf('postgresql.conf',
	"test_xlog_crypt.plaintext_relfilenode = $relnode\n");
$node->reload;
$node->poll_query_until('postgres',
	"SELECT current_setting('test_xlog_crypt.plaintext_relfilenode') = '$relnode'")
  or die "timed out waiting for the reload";
$node->safe_psql('postgres',
	"INSERT INTO plain_t VALUES ('RELCANARY_plain_41d7')");
$node->safe_psql('postgres', "INSERT INTO t VALUES ('RELCANARY_enc_9b02')");
$node->safe_psql('postgres', "SELECT pg_switch_wal()");
$node->stop('immediate');
is(wal_contains($node, 'RELCANARY_plain_41d7'), 1,
	'row of the opted-out relation is plaintext in WAL');
is(wal_contains($node, 'RELCANARY_enc_9b02'), 0,
	'row of another relation absent from WAL segments');
$node->start;
is( $node->safe_psql(
		'postgres',
		"SELECT (SELECT count(*) FROM plain_t), (SELECT count(*) FROM t)"),
	'1|3',
	'plaintext and encrypted records recovered together');

$node->stop;

# A record larger than the WAL buffers and several segments: its first pages
# are written out before its last ones are encrypted.
my $small = PostgreSQL::Test::Cluster->new('small');
$small->init(extra => ['--wal-segsize=1']);
$small->append_conf('postgresql.conf',
	"shared_preload_libraries = 'test_xlog_crypt'\n"
	  . "test_xlog_crypt.suffix = 20\n"
	  . "wal_buffers = 64kB\n"
	  . "min_wal_size = 2MB\n"
	  . "max_wal_size = 16MB\n");
$small->start;
$small->safe_psql('postgres', "CREATE TABLE t (v text)");
$small->safe_psql('postgres',
	"SELECT pg_logical_emit_message(true, 'crypt', repeat('HUGECANARY_5eed_', 200000))");
$small->safe_psql('postgres', "INSERT INTO t VALUES ('after huge record')");
$small->stop('immediate');
is(wal_contains($small, 'HUGECANARY_5eed_'), 0,
	'multi-segment record body absent from WAL segments');
$small->start;
is($small->safe_psql('postgres', "SELECT count(*) FROM t"), '1',
	'records after the multi-segment record recovered');

$small->stop;
done_testing();
