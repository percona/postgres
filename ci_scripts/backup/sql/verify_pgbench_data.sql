-- Check last transaction timestamps to ensure no delay
SELECT MAX(tid) AS last_transaction FROM pgbench_history;

-- Check data integrity by comparing last 5 accounts
SELECT aid, bid FROM pgbench_accounts ORDER BY aid DESC LIMIT 5;

-- Check last account ID for consistency
SELECT MAX(aid) AS last_account_id FROM pgbench_accounts;

-- Detect if the query is running on a Replica (Standby)
SELECT pg_is_in_recovery() AS is_replica;

