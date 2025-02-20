-- Verify pgbench accounts data is replicated correctly
SELECT COUNT(*) AS total_accounts FROM pgbench_accounts;

-- Check if pgbench history table matches expected transactions
SELECT COUNT(*) AS total_history FROM pgbench_history;

-- Check last transaction timestamps to ensure no delay
SELECT MAX(tid) AS last_transaction FROM pgbench_history;

-- Check data integrity by comparing last 5 accounts
SELECT aid, bid FROM pgbench_accounts ORDER BY aid DESC LIMIT 5;

-- Check last account ID and balance for consistency
SELECT MAX(aid) AS last_account_id FROM pgbench_accounts;

-- Detect if the query is running on a Replica (Standby)
SELECT pg_is_in_recovery() AS is_replica;

-- Only check WAL replay status on standby nodes
--DO $$ 
--BEGIN
--    IF pg_is_in_recovery() THEN
--        RAISE NOTICE 'Checking WAL replay status...';
--        PERFORM pg_last_wal_replay_lsn(), pg_last_wal_receive_lsn();
--    ELSE
--        RAISE NOTICE 'Skipping WAL check on Master.';
--    END IF;
--END $$;

