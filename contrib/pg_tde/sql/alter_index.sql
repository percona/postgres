CREATE EXTENSION IF NOT EXISTS pg_tde;

SELECT pg_tde_add_key_provider_file('file-vault','/tmp/pg_tde_test_keyring.per');
SELECT pg_tde_set_principal_key('test-db-principal-key','file-vault');

SET default_table_access_method = "tde_heap";

CREATE TABLE concur_reindex_part (c1 int, c2 int) PARTITION BY RANGE (c1);
CREATE TABLE concur_reindex_part_0 PARTITION OF concur_reindex_part
  FOR VALUES FROM (0) TO (10) PARTITION BY list (c2);
CREATE TABLE concur_reindex_part_0_1 PARTITION OF concur_reindex_part_0
  FOR VALUES IN (1);
CREATE TABLE concur_reindex_part_0_2 PARTITION OF concur_reindex_part_0
  FOR VALUES IN (2);
-- This partitioned table will have no partitions.
CREATE TABLE concur_reindex_part_10 PARTITION OF concur_reindex_part
  FOR VALUES FROM (10) TO (20) PARTITION BY list (c2);
-- Create some partitioned indexes
CREATE INDEX concur_reindex_part_index ON ONLY concur_reindex_part (c1);
CREATE INDEX concur_reindex_part_index_0 ON ONLY concur_reindex_part_0 (c1);
ALTER INDEX concur_reindex_part_index ATTACH PARTITION concur_reindex_part_index_0;
-- This partitioned index will have no partitions.
CREATE INDEX concur_reindex_part_index_10 ON ONLY concur_reindex_part_10 (c1);
ALTER INDEX concur_reindex_part_index ATTACH PARTITION concur_reindex_part_index_10;
CREATE INDEX concur_reindex_part_index_0_1 ON ONLY concur_reindex_part_0_1 (c1);
ALTER INDEX concur_reindex_part_index_0 ATTACH PARTITION concur_reindex_part_index_0_1;
CREATE INDEX concur_reindex_part_index_0_2 ON ONLY concur_reindex_part_0_2 (c1);
ALTER INDEX concur_reindex_part_index_0 ATTACH PARTITION concur_reindex_part_index_0_2;
SELECT relid, parentrelid, level FROM pg_partition_tree('concur_reindex_part_index')
  ORDER BY relid, level;
SELECT relid, parentrelid, level FROM pg_partition_tree('concur_reindex_part_index')
  ORDER BY relid, level;
SELECT relid, parentrelid, level FROM pg_partition_tree('concur_reindex_part_index')
  ORDER BY relid, level;
DROP TABLE concur_reindex_part;
DROP EXTENSION pg_tde;
RESET default_table_access_method;
