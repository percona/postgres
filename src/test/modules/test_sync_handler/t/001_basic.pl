# Copyright (c) 2026, PostgreSQL Global Development Group
#
# Basic test for register_sync_handler() dispatch.
#
# Verifies that a custom sync handler registered via register_sync_handler()
# in _PG_init() receives callback invocations from ProcessSyncRequests() at
# CHECKPOINT time, that identical FileTags coalesce via HASH_BLOBS
# deduplication, that distinct FileTags produce distinct callbacks, and
# that an idle checkpoint does not re-dispatch entries that were already
# processed (cycle_ctr skip).

use strict;
use warnings FATAL => 'all';

use PostgreSQL::Test::Cluster;
use PostgreSQL::Test::Utils;
use Test::More;

my $node = PostgreSQL::Test::Cluster->new('sync_handler');
$node->init;
$node->append_conf(
	'postgresql.conf', q{
shared_preload_libraries = 'test_sync_handler'
# TAP clusters set fsync = off by default for speed; re-enable here so
# that ProcessSyncRequests actually dispatches our sync handler callback.
fsync = on
});
$node->start;
$node->safe_psql('postgres', 'CREATE EXTENSION test_sync_handler');

# The handler ID must be >= SYNC_HANDLER_FIRST_DYNAMIC. Built-ins
# currently occupy IDs 0..4, so the first extension handler should be
# at least 5.
my $id = $node->safe_psql('postgres', 'SELECT test_sync_handler_id()');
ok($id >= 5,
	"handler id $id is >= SYNC_HANDLER_FIRST_DYNAMIC (built-ins = 5)")
  or diag("got id=$id");

# Baseline: no dispatches before we queue anything.
my $baseline =
  $node->safe_psql('postgres', 'SELECT test_sync_handler_count()');
is($baseline, '0', 'baseline dispatch count is zero');

# Queue 5 distinct FileTags (differing in segno only) and checkpoint.
# Expect 5 callback invocations since they are all distinct hash keys.
$node->safe_psql(
	'postgres', q{
SELECT test_sync_handler_register(1);
SELECT test_sync_handler_register(2);
SELECT test_sync_handler_register(3);
SELECT test_sync_handler_register(4);
SELECT test_sync_handler_register(5);
});
$node->safe_psql('postgres', 'CHECKPOINT');
my $after_distinct =
  $node->safe_psql('postgres', 'SELECT test_sync_handler_count()');
is($after_distinct, '5',
	'5 distinct FileTags produce 5 sync_syncfiletag callbacks')
  or diag("got $after_distinct");

# Queue 10 duplicate FileTags (same segno 42) and checkpoint.
# Expect exactly 1 additional callback because pendingOps uses HASH_BLOBS
# and collapses identical FileTags into a single hash entry.
$node->safe_psql(
	'postgres', q{
SELECT test_sync_handler_register(42);
SELECT test_sync_handler_register(42);
SELECT test_sync_handler_register(42);
SELECT test_sync_handler_register(42);
SELECT test_sync_handler_register(42);
SELECT test_sync_handler_register(42);
SELECT test_sync_handler_register(42);
SELECT test_sync_handler_register(42);
SELECT test_sync_handler_register(42);
SELECT test_sync_handler_register(42);
});
$node->safe_psql('postgres', 'CHECKPOINT');
my $after_coalesce =
  $node->safe_psql('postgres', 'SELECT test_sync_handler_count()');
is($after_coalesce, '6',
	'10 duplicate FileTags coalesce via HASH_BLOBS to 1 additional callback')
  or diag("got $after_coalesce");

# Second CHECKPOINT with no new requests. The count must stay the same:
# every entry from the previous checkpoint was processed and removed
# from pendingOps, and no new entries have been queued, so
# ProcessSyncRequests has nothing to dispatch.
$node->safe_psql('postgres', 'CHECKPOINT');
my $after_idle =
  $node->safe_psql('postgres', 'SELECT test_sync_handler_count()');
is($after_idle, '6', 'idle checkpoint does not re-dispatch')
  or diag("got $after_idle");

$node->stop;

done_testing();
