package PGTDE;

use PostgreSQL::Test::Cluster;
use PostgreSQL::Test::Utils;

use File::Basename;
use File::Compare;
use Test::More;

# Expected .out filename of TAP testcase being executed. These are already part of repo under t/expected/*.
our $expected_filename_with_path;

# Result .out filename of TAP testcase being executed. Where needed, a new *.out will be created for each TAP test.
our $out_filename_with_path;

# Runtime output file that is used only for debugging purposes for comparison to PGSS, blocks and timings.
our $debug_out_filename_with_path;

my $expected_folder = "t/expected";
my $results_folder = "t/results";

sub psql
{
	my ($node, $dbname, $sql) = @_;

	my (undef, $stdout, $stderr) = $node->psql($dbname, $sql,
		extra_params => [ '-a', '-Pformat=aligned', '-Ptuples_only=off' ]);

	if ($stdout ne '')
	{
		append_to_result_file($stdout);
	}

	if ($stderr ne '')
	{
		append_to_result_file($stderr);
	}
}

sub append_to_result_file
{
	my ($str) = @_;

	append_to_file($out_filename_with_path, $str . "\n");
}

sub append_to_debug_file
{
	my ($str) = @_;

	append_to_file($debug_out_filename_with_path, $str . "\n");
}

sub setup_files_dir
{
	my ($test_filename) = @_;

	unless (-d $results_folder)
	{
		mkdir $results_folder
		  or die "Can't create folder $results_folder: $!\n";
	}

	my ($test_name) = $test_filename =~ /([^.]*)/;

	$expected_filename_with_path = "${expected_folder}/${test_name}.out";
	$out_filename_with_path = "${results_folder}/${test_name}.out";
	$debug_out_filename_with_path =
	  "${results_folder}/${test_name}.out.debug";

	if (-f $out_filename_with_path)
	{
		unlink($out_filename_with_path)
		  or die
		  "Can't delete already existing $out_filename_with_path: $!\n";
	}
}

sub compare_results
{
	return compare($expected_filename_with_path, $out_filename_with_path);
}

# Common TDE helpers

# Check if the encryption status of a table is as expected and return 't' or 'f'
sub check_encryption_status
{
	my ($node, $table_name, $expected) = @_;
	my $result =
	  safe_psql('postgres', "SELECT pg_tde_is_encrypted('$table_name')");
	append_to_result_file($node->name . ": encryption check result for $table_name = $result");
	is($result, $expected, "Check encryption status for '$table_name' on " . $node->name);
}

# Set up pg_tde extension and add a global key provider and set the server key
sub setup_pg_tde_global_environment
{
	my ($node, $key_name, $provider_name, $provider_path) = @_;
	psql($node, 'postgres', 'CREATE EXTENSION IF NOT EXISTS pg_tde;');
	psql($node, 'postgres',
		"SELECT pg_tde_add_global_key_provider_file('$provider_name', '$provider_path');");
	psql($node, 'postgres',
		"SELECT pg_tde_set_server_key_using_global_key_provider('$key_name', '$provider_name');");
}

# Set up pg_tde extension and add a database key provider and set the database key
sub setup_pg_tde_db_environment
{
	my ($node, $key_name, $provider_name, $provider_path) = @_;
	psql($node, 'postgres', 'CREATE EXTENSION IF NOT EXISTS pg_tde;');
	psql($node, 'postgres',
		"SELECT pg_tde_add_database_key_provider_file('$provider_name', '$provider_path');");
	psql($node, 'postgres',
		"SELECT pg_tde_set_key_using_database_key_provider('$key_name', '$provider_name');");
}

# Set up pg_tde in postgresql.conf
sub enable_pg_tde_in_conf
{
	my ($node) = @_;
	$node->append_conf('postgresql.conf', "shared_preload_libraries = 'pg_tde'");
}

# Set default table access method to tde_heap
sub set_default_table_am_tde_heap
{
	my ($node) = @_;
	$node->append_conf('postgresql.conf', "default_table_access_method = 'tde_heap'");
}

# Set pg_tde.wal_encrypt and restart the server
sub set_wal_encryption_and_restart
{
	my ($node, $value) = @_;

	die "Invalid value for wal_encrypt: must be 'on' or 'off'\n"
		unless $value eq 'on' || $value eq 'off';

	psql($node, 'postgres', "ALTER SYSTEM SET pg_tde.wal_encrypt = $value;");
	append_to_result_file("-- server restart with wal encryption = $value");
	$node->restart;
}

1;
