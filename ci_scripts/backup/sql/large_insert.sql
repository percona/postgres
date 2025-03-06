BEGIN;
INSERT INTO pgbench_accounts (aid, bid, abalance, filler)
SELECT i, 1, 0, repeat('x', 84) FROM generate_series(1000001, 2000000) AS i;
COMMIT;
