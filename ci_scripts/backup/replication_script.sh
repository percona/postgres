#!/bin/bash
# This script is used to set up replication with TDE enabled
export TDE_MODE=1

# Paths and Configurations
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"
INSTALL_DIR="$SCRIPT_DIR/../../pginst"
export PATH=$INSTALL_DIR/bin:$PATH

# PostgreSQL Data Directories
MASTER_DATA=$INSTALL_DIR/primary
STANDBY1_DATA=$INSTALL_DIR/standby1
STANDBY2_DATA=$INSTALL_DIR/standby2
ARCHIVE_DIR=$INSTALL_DIR/archive
SQL_DIR=$SCRIPT_DIR/backup/sql
EXPECTED_DIR=$SCRIPT_DIR/backup/expected
ACTUAL_DIR=$SCRIPT_DIR/actual

# PostgreSQL Configuration
MASTER_PORT=55433
STANDBY1_PORT=55434
STANDBY2_PORT=55435
DB_NAME=tde_db
TABLE_NAME="emp"
SEARCHED_TEXT="SMITH"

# pgbench Configuration
SCALE=50        # ~5 million rows
DURATION=300    # 5 minutes test
CLIENTS=16      # Moderate concurrent load
THREADS=4       # Suitable for 4+ core machines

# Log File
LOGFILE=$INSTALL_DIR/replication_test.log

# PASS/FAIL Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Ensure necessary directories exist
mkdir -p $EXPECTED_DIR $ACTUAL_DIR $ARCHIVE_DIR

# Logging Function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" |tee -a "$LOGFILE"
}

check_success() {
    if [ $? -eq 0 ]; then
        echo "✅[PASS]✅ $1" | tee -a $RESULTS_LOG
        ((TESTS_PASSED++))
    else
        echo "❌[FAIL]❌ $1" | tee -a $RESULTS_LOG
        ((TESTS_FAILED++))
    fi
}

# Function to run SQL files and capture results with PASS/FAIL reporting
run_sql() {
    local sql_file=$1
    local db_name="${2:-$DB_NAME}"
    local port="${3:-$MASTER_PORT}"
    local out_dir="${4:-$ACTUAL_DIR}"
    local file_name=$(basename "$sql_file" .sql)
    local log_file="$out_dir/$file_name.out"

    # Ensure output directory exists
    mkdir -p "$out_dir"

    # Remove old log file if exists
    [ -f "$log_file" ] && rm -f "$log_file"

    # Run SQL and capture output
    psql -d "$db_name" -p "$port" -e -a -f "$SQL_DIR/$sql_file" > "$log_file" 2>&1
}

# Function to compare expected vs. actual SQL execution output with PASS/FAIL reporting
verify_output() {
    local sql_file=$1
    local actual_dir=$2
    local file_name=$(basename "$sql_file" .sql)
    local expected_file="$EXPECTED_DIR/$file_name.out"
    local actual_file="$actual_dir/$file_name.out"
    local diff_file="$actual_dir/$file_name.diff"

    #log_message "🔎 Verifying output for: $sql_file"

    # Ensure expected output file exists
    if [ ! -f "$expected_file" ]; then
        log_message "❌ Expected output file missing: $expected_file"
        return 1
    fi

    # Ensure actual output file exists
    if [ ! -f "$actual_file" ]; then
        log_message "❌ Actual output file missing: $actual_file"
        return 1
    fi

    # Remove old diff file if exists
    [ -f "$diff_file" ] && rm -f "$diff_file"

    # Compare files
    if diff -q "$expected_file" "$actual_file" > /dev/null; then
        log_message "✅ Output matches expected result."
    else
        diff "$expected_file" "$actual_file" > "$diff_file"
        log_message "❌ Output mismatch. See diff file: $diff_file"
        return 1
    fi
}

# Function to configure the primary PostgreSQL server
configure_primary_server() {
    log_message "Configuring Primary PostgreSQL Server... $MASTER_PORT"

    # Run TDE configuration script
    source "$SCRIPT_DIR/configure-tde-server.sh" "$MASTER_DATA" "$MASTER_PORT" >> $LOGFILE 2>&1

    # Update postgresql.conf with replication settings
    cat >> "$MASTER_DATA/postgresql.conf" <<EOF
archive_command = 'rsync -a %p ${ARCHIVE_DIR}/%f'
archive_mode = on
wal_level = replica
max_wal_senders = 10
min_wal_size = '80MB'
max_wal_size = '10GB'
hot_standby = on
wal_log_hints = on
listen_addresses = '*'

logging_collector = on
log_directory = 'log'
log_filename = 'postgresql.log'
log_replication_commands = on
log_checkpoints = on
log_recovery_conflict_waits = on
EOF

    # Update pg_hba.conf to allow replication connections
    cat >> "$MASTER_DATA/pg_hba.conf" <<EOF
# Allow replication connections
local replication replication trust
EOF


    # Restart the primary server
    echo "Restarting Primary Server..."
    pg_ctl -D "$MASTER_DATA" -l "$INSTALL_DIR/server.log" -o "-p ${MASTER_PORT}" restart >> $LOGFILE 2>&1

    # Create replication user
    psql -p "$MASTER_PORT" -c "CREATE USER replication WITH REPLICATION;" >> $LOGFILE 2>&1

    # Create TDE-enabled database
    createdb -p "$MASTER_PORT" "$DB_NAME" >> $LOGFILE 2>&1

    # Enable pg_tde extension
    psql -p "$MASTER_PORT" -d "$DB_NAME" -c "CREATE EXTENSION pg_tde;" >> $LOGFILE 2>&1

    # Set TDE principal key
    psql -p "$MASTER_PORT" -d "$DB_NAME" -c "SELECT pg_tde_set_default_principal_key('default-principal-key','reg_file-global',false);" >> $LOGFILE 2>&1

    # Load sample data into the database
    psql -p "$MASTER_PORT" -d "$DB_NAME" -f "$SQL_DIR/sample_data.sql" >> $LOGFILE 2>&1

    echo "Primary Server Configuration Completed! " >> $LOGFILE 2>&1
}

# Function to configure the standby PostgreSQL server
configure_standby() {
    local standby_data=$1
    local standby_port=$2
    local standby_log="$standby_data/server.log"

    log_message "Configuring Standby Server on Port: $standby_port..."

    # Ensure the standby data directory is clean
    if [ -d "$standby_data" ]; then
        if pg_ctl -D "$standby_data" status -o "-p $standby_port" >/dev/null 2>&1; then
            pg_ctl -D "$standby_data" stop -o "-p $standby_port" >> $LOGFILE 2>&1
        fi
        rm -rf "$standby_data"
    fi

    # Create a fresh base backup from the primary
    pg_basebackup -D "$standby_data" -U replication -p "$MASTER_PORT" -Xs -R -P >> $LOGFILE

    # Update the postgresql.conf file with the correct port and log settings
    cat >> $standby_data/postgresql.conf <<EOF
port = ${standby_port}
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql.log'
log_replication_commands = on
log_checkpoints = on
log_recovery_conflict_waits = on
EOF

    # Start the standby server
    echo "Starting Standby Server on Port: $standby_port..."
    pg_ctl -D "$standby_data" -l "$standby_log" start >> $LOGFILE 2>&1

    # Give some time for the standby to initialize
    sleep 10

    # Verify that the standby is running and connected to the primary
    psql -h "localhost" -p "$standby_port" -d postgres -c "SELECT pg_is_in_recovery();" | grep -q "t"
    if [ $? -eq 0 ]; then
       log_message "✅ Standby Server is in Recovery Mode (Replication Active)"
    else
        log_message "❌ Standby Server is NOT in recovery mode! Replication may have failed."
        return 1
    fi
}

# Function to insert data into the database using SQL file
insert_data(){
    local sql_file="${1:-sampe_data.sql}"
    local db_name="${2:-$DB_NAME}"
    local port="${3:-$MASTER_PORT}"

    psql -p "$port" -d "$db_name" -f "$SQL_DIR/$sql_file" >> "$LOGFILE" 2>&1
}

# Initialize pgbench on Master
initialize_pgbench() {
    log_message "Initializing pgbench with scale factor $SCALE on database: $DB_NAME and (port: $MASTER_PORT)..."
    pgbench -U postgres -i -s $SCALE -d $DB_NAME -p $MASTER_PORT >> $LOGFILE 2>&1
    if [ $? -eq 0 ]; then
        log_message "✅ Pgbench Initialization done..."
    else
        log_message "❌ Pgbench Initialization failed..."
    fi
}

# Run pgbench Transactions
run_pgbench() {
    local duration="${1:-$DURATION}"
    local clients="${2:-$CLIENTS}"
    local threads="${3:-$THREADS}"
    sync && sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
    log_message "Running pgbench with $clients clients and $threads threads for $duration seconds..."
    pgbench -T $duration -c $clients -j $threads -M prepared -d $DB_NAME -p $MASTER_PORT >> $LOGFILE 2>&1
    if [ $? -eq 0 ]; then
        log_message "✅ Pgbench Run Completed..."
    else
        log_message "❌ Pgbench Run failed..."
    fi
}

# Function to promote the standby node to master
promote_standby() {
    local promoted_port="${1:-$STANDBY1_PORT}"
    local promoted_data="${2:-$STANDBY1_DATA}"
    local promoted_log="$promoted_data/server.log"

    log_message "🟢 Promoting Standby Server (Port: $promoted_port) to Primary..."
    pg_ctl -D "$promoted_data" promote -l $promoted_log
    sleep 30  # Allow time for promotion to take effect

    # Check if the promoted node is running
    pg_ctl -D "$promoted_data" status -o "-p $promoted_port"
    if [ $? -eq 0 ]; then
        log_message "✅ Standby Promoted to Master Successfully. $promoted_port"
    else
        log_message "❌ Standby Promoted server is not running. $promoted_port"
        return 1
    fi
    psql -h "localhost" -p "$promoted_port" -d postgres -c "SELECT pg_is_in_recovery();" | grep -q "f"
    if [ $? -eq 0 ]; then
       log_message "✅ The standby is now the new Primary Server. $promoted_port"
    else
        log_message "❌ The standby is still in recovery mode, meaning the promotion did NOT work."
        return 1
    fi
}

# Function to verify data consistency between Master and Standby nodes
verify_database_data() {
    local sql_file="${1:-verify_sample_data.sql}"
    local standby_ports=("$STANDBY1_PORT" "$STANDBY2_PORT")
    local standby_dirs=("${ACTUAL_DIR}/standby1" "${ACTUAL_DIR}/standby2")

    # Verify sample data on all standby nodes
    for i in "${!standby_ports[@]}"; do
        log_message "🔎 Verifying $sql_file data on standby (Port: ${standby_ports[$i]})..."
        run_sql "$sql_file" "$DB_NAME" "${standby_ports[$i]}" "${standby_dirs[$i]}"
        verify_output "$sql_file" "${standby_dirs[$i]}"
    done
}

# Function to verify that data is encrypted at rest
verify_encrypted_data_at_rest() {
    local table_name="${1:-$TABLE_NAME}"
    local search_text="${2:-$SEARCHED_TEXT}"
    local pg_port="${3:-$MASTER_PORT}"
    local db_name="${4:-$DB_NAME}"

    # Retrieve the data file path
    local pg_relation_filepath
    local data_dir_path
    local file_name

    pg_relation_filepath=$(psql -p "$pg_port" -d "$db_name" -t -c "SELECT pg_relation_filepath('$table_name');" | xargs)
    data_dir_path=$(psql -p "$pg_port" -d "$db_name" -t -c "SHOW data_directory;" | xargs)
    file_name="$data_dir_path/$pg_relation_filepath"

    # Check if the file exists
    if [[ ! -f "$file_name" ]]; then
        log_message "❌ Data file not found: $file_name"
        return 1
    fi

    # Extract first 10 lines of raw data for reference
    local raw_data
    raw_data=$(sudo hexdump -C "$file_name" | head -n 10 || true)
    echo "$raw_data" >> "$LOGFILE"

    # Check for readable text in the file (unencrypted data detection)
    if sudo strings "$file_name" | grep -q "$search_text"; then
        log_message "❌ Readable text detected! Data appears UNENCRYPTED."
        return 1
    else
        log_message "✅ Data appears to be ENCRYPTED!"
    fi
}

# Function to verify data consistency between Master and Standby nodes
verify_data_ondisk() {
    local standby_ports=("$MASTER_PORT" "$STANDBY1_PORT" "$STANDBY2_PORT")
    local standby_labels=("Master" "Standby1" "Standby2")

    for i in "${!standby_ports[@]}"; do
        log_message "🔎 Verifying encryption on ${standby_labels[$i]} (Port: ${standby_ports[$i]})..."
        verify_encrypted_data_at_rest "$TABLE_NAME" "$SEARCHED_TEXT" "${standby_ports[$i]}" "$DB_NAME"
    done
}

check_replication_status(){
    local port="${1:-$MASTER_PORT}"
    local data_dir_path=$(psql -p "$port" -d "$DB_NAME" -t -c "SHOW data_directory;" | xargs)

    replication_status=$(psql -p "$port" -d "$DB_NAME" -t -A -c "SELECT state, sent_lsn, write_lsn, flush_lsn, replay_lsn  FROM pg_stat_replication;")
    while IFS="|" read -r state sent_lsn write_lsn flush_lsn replay_lsn; do
        # Check if replication is streaming
        if [[ "$state" == "streaming" ]]; then
            log_message "✅ Replication is active. State: $state"
        else
            log_message "❌ Replication is NOT streaming! State: $state"
            return 1
        fi

        # Check if LSN values match
        if [[ "$sent_lsn" == "$write_lsn" && "$write_lsn" == "$flush_lsn" && "$flush_lsn" == "$replay_lsn" ]]; then
            log_message "✅ Data insertion fully replicated."
        else
            log_message "❌ WARNING: LSNs do not match! There may be replication lag."
            echo "Sent LSN: $sent_lsn | Write LSN: $write_lsn | Flush LSN: $flush_lsn | Replay LSN: $replay_lsn"
            return 1
        fi
    done <<< "$replication_status"
}

# Check WAL statistics on the Master node
check_master_wal_stats() {
    log_message "🔍 Checking WAL Statistics on Master (Port: $MASTER_PORT)..."

    # Extract WAL statistics
    read wal_records wal_bytes wal_write <<< $(psql -p "$MASTER_PORT" -d "$DB_NAME" -t -A -c "SELECT wal_records, wal_bytes, wal_write FROM pg_stat_wal;")

    # Log retrieved values
    log_message "📊 WAL Records: $wal_records | WAL Bytes: $wal_bytes | WAL Writes: $wal_write"
    master_wal_records=$(psql -p "$MASTER_PORT" -d "$DB_NAME" -t -A -c "SELECT wal_records FROM pg_stat_wal;")

    # Validate WAL Activity
    if [[ $master_wal_records -gt 0 ]]; then
        log_message "✅ WAL Activity is Active on Master"
    else
        log_message "❌ No WAL Activity Detected on Master!"
        return 1
    fi
}


# Check replication by checking if all LSNs match and Detects lag issues
check_master_slave_wal_lsn() {
    local master_lsn
    local standby1_lsn
    local standby2_lsn

    log_message "🔍 Checking WAL LSN on Master and Slave Nodes..."

    master_lsn=$(psql -p "$MASTER_PORT" -d "$DB_NAME" -t -c "SELECT pg_current_wal_lsn();")
    standby1_lsn=$(psql -p "$STANDBY1_PORT" -d "$DB_NAME" -t -c "SELECT pg_last_wal_replay_lsn();")
    standby2_lsn=$(psql -p "$STANDBY2_PORT" -d "$DB_NAME" -t -c "SELECT pg_last_wal_replay_lsn();")

    if [ "$master_lsn" == "$standby1_lsn" ] && [ "$master_lsn" == "$standby2_lsn" ]; then
        log_message "✅ Replication LSNs Match on all nodes."
    else
        log_message "❌ Replication LSNs Mismatch Detected!"
        echo "Master: $master_lsn| Standby1: $standby1_lsn | Standby2: $standby2_lsn"
        return 1
    fi
}

check_wal_replay_status() {
    local port="${1:-$STANDBY1_PORT}"
    local db_name="${2:-tde_db}"

    log_message "🔍 Checking WAL Replay Status on Port: $port..."

    # Run SQL directly in Bash
    wal_status=$(psql -p "$port" -d "$db_name" -t -A -c "
        DO \$\$
        DECLARE
            replay_lsn TEXT;
            receive_lsn TEXT;
        BEGIN
            IF pg_is_in_recovery() THEN
                SELECT pg_last_wal_replay_lsn(), pg_last_wal_receive_lsn()
                INTO replay_lsn, receive_lsn;

                RAISE NOTICE '✅ WAL Replay LSN: %', replay_lsn;
                RAISE NOTICE '✅ WAL Receive LSN: %', receive_lsn;
            ELSE
                RAISE NOTICE '❌ Skipping WAL check: Not a Standby Node';
            END IF;
        END \$\$;
    ")
}

verify_replication_status(){
    check_replication_status
    rvalue1=$?
    check_master_wal_stats
    rvalue2=$?
    check_master_slave_wal_lsn
    rvalue3=$?
    check_wal_replay_status $STANDBY1_PORT
    rvalue4=$?
    check_wal_replay_status $STANDBY2_PORT
    rvalue5=$?
    if ! [ $rvalue1 -eq 0 ] || ! [ $rvalue2 -eq 0 ] || ! [ $rvalue3 -eq 0 ] || ! [ $rvalue4 -eq 0 ] || ! [ $rvalue5 -eq 0 ]; then
        return 1
    fi
}

# Analyze PostgreSQL logs for replication errors
analyze_logs() {
    local port="${1:-$MASTER_PORT}"
    local data_dir_path=$(psql -p "$port" -d "$DB_NAME" -t -c "SHOW data_directory;" | xargs)
    local log_dir_path=$(psql -p "$port" -d "$DB_NAME" -t -c "SHOW log_directory;" | xargs)
    local log_file="$data_dir_path/$log_dir_path/postgresql.log"

    # Ensure the log file exists before searching
    if [[ ! -f "$log_file" ]]; then
        log_message "PostgreSQL log file not found: $log_file"
        return 1
    fi

    temp_log=$(mktemp)

    # Extract errors related to replication and WAL for Master and Standby nodes
    grep -Ei 'replication|error|fatal|wal' "$log_file" |grep -v 'FATAL:  terminating walreceiver process due to administrator command' | tail -20 | tee -a "$LOGFILE" > "$temp_log"

    # Check if errors exist in extracted logs
    if grep -Ei 'fatal|error' "$temp_log"; then
        log_message "❌ Errors detected in PostgreSQL logs! Check $log_file for details."
        rm -f "$temp_log"
        return 1
    else
        log_message "✅ No Error message in Server log: ($port)"
    fi

    # Clean up temporary file
    rm -f "$temp_log"
}

# Function to stop or start the PostgreSQL server
server_operation(){
    local operation=$1
    local port=$2
    local data_dir=$3
    local log_file=$data_dir/server.log

    pg_ctl -D $data_dir $operation -l $log_file -o "-p $port" >> $LOGFILE 2>&1
}

# Function to perform DML operations on the primary database
perform_transactions() {
    log_message "📝 Performing some DML on Primary Database ($DB_NAME)..."
    psql -p "$MASTER_PORT" -d "$DB_NAME" -c "INSERT INTO emp (empno, ename, sal) VALUES (1001, 'John Doe', 50000);" > /dev/null 2>&1
    psql -p "$MASTER_PORT" -d "$DB_NAME" -c "UPDATE emp SET sal = sal + 500 WHERE empno = 1001;" > /dev/null 2>&1
}

### **📌 Verify Data Replication After Recovery**
verify_data_after_failure() {
    local port=$1
    log_message "🔍 Verifying Replication on Standby..."
    psql -p "$port" -d "$DB_NAME" -c "SELECT * FROM emp WHERE empno = 1001;" > "$ACTUAL_DIR/replication_check.out"

    if grep -q "John Doe" "$ACTUAL_DIR/replication_check.out"; then
        log_message "✅ Replication Successful After Recovery"
    else
        log_message "❌ [FAIL] Replication Failed After Recovery!"
        return 1
    fi
}

# Function to verify large data insertion and replication
verify_large_insert(){
    log_message "🔍 Insert large dataset on Port:($MASTER_PORT)..."
    insert_data large_insert.sql $DB_NAME $MASTER_PORT
    log_message "🔍 Verify Replication status after large data insertion. Sleep 15 Seconds..."
    sleep 15
    verify_replication_status
    rvalue1=$?

    log_message "🔍 Checking if Slave caught up after large data insertion..."
    master_max_aid=$(psql -p "$MASTER_PORT" -d "$DB_NAME" -t -A -c "SELECT MAX(aid) FROM pgbench_accounts;")
    standby1_max_aid=$(psql -p "$STANDBY1_PORT" -d "$DB_NAME" -t -A -c "SELECT MAX(aid) FROM pgbench_accounts;")
    standby2_max_aid=$(psql -p "$STANDBY1_PORT" -d "$DB_NAME" -t -A -c "SELECT MAX(aid) FROM pgbench_accounts;")
    if [ "$master_max_aid" == "$standby1_max_aid" ] && [ "$master_max_aid" == "$standby2_max_aid" ]; then
        log_message "✅ Replication caught up on all nodes."
    else
        log_message "❌ Replication lag detected!"
        echo "Master: $master_max_aid | Standby1: $standby1_max_aid | Standby2: $standby2_max_aid"
        return 1
    fi
    return $rvalue1
}

verify_pgbench_table_data_count(){
    master_account_count=$(psql -p "$MASTER_PORT" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) AS total_history FROM pgbench_accounts;")
    standby1_account_count=$(psql -p "$STANDBY1_PORT" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) AS total_history FROM pgbench_accounts;")
    standby2_account_count=$(psql -p "$STANDBY1_PORT" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) AS total_history FROM pgbench_accounts;")
    if [ "$master_account_count" == "$standby1_account_count" ] && [ "$master_account_count" == "$standby2_account_count" ]; then
        log_message "✅ Pgbench_account count is same on all nodes:  $master_account_count"
    else
        log_message "❌ Pgbench_account count is differnt on all nodes!"
        echo "Master: $master_account_count | Standby1: $standby1_account_count | Standby2: $standby2_account_count"
        retun 1
    fi

    master_history_count=$(psql -p "$MASTER_PORT" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) AS total_history FROM pgbench_history;")
    standby1_history_count=$(psql -p "$STANDBY1_PORT" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) AS total_history FROM pgbench_history;")
    standby2_history_count=$(psql -p "$STANDBY1_PORT" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) AS total_history FROM pgbench_history;")
    if [ "$master_history_count" == "$standby1_history_count" ] && [ "$master_history_count" == "$standby2_history_count" ]; then
        log_message "✅ Pgbench_history count is same on all nodes."
    else
        log_message "❌ Pgbench_history count is differnt on all nodes!"
        echo "Master: $master_history_count | Standby1: $standby1_history_count | Standby2: $standby2_history_count"
        return 1
    fi
}

# Function to verify data consistency after promotion
verify_data_sync() {
    local old_master_port="${1:-$MASTER_PORT}"
    local new_primary_port="${2:-$STANDBY1_PORT}"
    local table_name="${3:-$TABLE_NAME}"
    log_message "🔍 Verifying Data Consistency After Promotion..."

    # Run count queries on old master & new primary
    old_master_count=$(psql -p "$old_master_port" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM $table_name;")
    new_primary_count=$(psql -p "$new_primary_port" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM $table_name;")

    if [[ "$old_master_count" -eq "$new_primary_count" ]]; then
        log_message "✅ Data is Synchronized After Promotion"
    else
        log_message "❌ WARNING: Data Mismatch! Old Master: $old_master_count, New Primary: $new_primary_count"
        return 1
    fi
}

# Simulate replica failure and verify that it can rsync after restart
verify_replica_failure(){
    log_message "🔍 Simulating Standby Failure..."
    log_message "🔍 Stopping Standby Server Port:($STANDBY2_PORT)..."
    server_operation stop $STANDBY2_PORT $STANDBY2_DATA
    initialize_pgbench
    run_pgbench 120 16 4
    perform_transactions
    log_message "🔍 Starting Standby Server Port:($STANDBY2_PORT)..."
    server_operation start $STANDBY2_PORT $STANDBY2_DATA
    log_message "🔍 Wait for 15 Seconds to sync data on Standby Server Port:($STANDBY2_PORT)..."
    sleep 30  # Allow time for the standby to sync

    # Check replication lag after running pgbench
    log_message "🔍 Verify Replication Status after Replica Failure..."
    verify_replication_status
    rvalue1=$?
    verify_data_after_failure $STANDBY2_PORT
    rvalue2=$?
    if ! [ $rvalue1 -eq 0 ] || ! [ $rvalue2 -eq 0 ]; then
        return 1
    fi
}

# Function to run the pgbench test suite
pgbench_test_suite() {
    # Initialize pgbench on the master node
    initialize_pgbench
    # Run pgbench on the master node
    run_pgbench

    # Check replication lag after running pgbench
    log_message "🔍 Verify Replication status After pgbench Run..."
    verify_replication_status
    rvalue1=$?

    # Verify that pgbench data was replicated correctly
    log_message "🔍 Verify database data After pgbench Run..."
    verify_pgbench_table_data_count
    rvalue2=$?
    verify_database_data verify_pgbench_data.sql
    rvalue3=$?

    # Verify log files on master node for errors
    log_message "🔍 Analyse Log After pgbench Run $MASTER_PORT..."
    analyze_logs $MASTER_PORT
    rvalue4=$?
    # Verify log files on standby1 node for errors
    log_message "🔍 Analyse Log After pgbench Run $STANDBY1_PORT..."
    analyze_logs $STANDBY1_PORT
    rvalue5=$?
    # Verify log files on standby2 node for errors
    log_message "🔍 Analyse Log After pgbench Run $STANDBY2_PORT..."
    analyze_logs $STANDBY2_PORT
    rvalue6=$?
    if ! [ $rvalue1 -eq 0 ] || ! [ $rvalue2 -eq 0 ] || ! [ $rvalue3 -eq 0 ] || ! [ $rvalue4 -eq 0 ] || ! [ $rvalue5 -eq 0 ] || ! [ $rvalue6 -eq 0 ]; then
        return 1
    fi
}

verify_standby_promotion(){
    local master_port="${1:-$MASTER_PORT}"
    local standby_port="${2:-$STANDBY1_PORT}"
    local standby_data="${3:-$STANDBY1_DATA}"
    log_message "🔍 Verify Replication status Before Promotion..."
    verify_replication_status $master_port
    rvalue1=$?
    promote_standby $standby_port $standby_data
    rvalue2=$?
    verify_data_sync $master_port $standby_port pgbench_accounts
    rvalue3=$?
    #log_message "🔍 Verify Replication status After Promotion..."
    #verify_replication_status $standby_port
    if ! [ $rvalue1 -eq 0 ] || ! [ $rvalue2 -eq 0 ] || ! [ $rvalue3 -eq 0 ]; then
        return 1
    fi
}

# Function to rewind the master node using pg_rewind
pg_rewind() {
    pg_rewind --target-pgdata=$MASTER_DATA --source-server="port=$STANDBY1_PORT user=postgres dbname=$DB_NAME"  > $ACTUAL_DIR/pg_rewind.log 2>&1
}

# Function to summarize test results
summarize_results() {
    echo "=============================================" |tee -a $LOGFILE
    echo "======== Test Suite Summary =======" |tee -a $LOGFILE
    echo "=============================================" |tee -a $LOGFILE
    log_message "✅ Tests Passed: $TESTS_PASSED"
    log_message "❌ Tests Failed: $TESTS_FAILED"

    if [ "$TESTS_FAILED" -eq 0 ]; then
        log_message "✅ ALL TESTS PASSED! Replication is working correctly."
        exit 0
    else
        log_message "❌ SOME TESTS FAILED! Check logs for details."
        exit 1
    fi
    echo "=============================================" |tee -a $LOGFILE
    echo "======== Test Suite Completed  ==============" |tee -a $LOGFILE
    echo "=============================================" |tee -a $LOGFILE
}

#======================================================
# Main Function to Run All Tests
run_tests() {
    log_message "=== Starting PostgreSQL Replication Test Suite ==="
    configure_primary_server
    check_success "Primary Server Configuration"

    configure_standby $STANDBY1_DATA $STANDBY1_PORT
    check_success "Standby1 Server Configuration"

    configure_standby $STANDBY2_DATA $STANDBY2_PORT
    check_success "Standby2 Server Configuration"

    log_message "[TESTCASE]- Verify Data Status After Setup Replication..."
    verify_database_data verify_sample_data.sql
    check_success "Data Verification Status After Setup Replication"

    insert_data incremental_data.sql $DB_NAME $MASTER_PORT
    sleep 3

    log_message "[TESTCASE]- Verify Incremental Data Status..."
    verify_database_data verify_incremental_data.sql
    check_success "Incremental Data Verification"

    log_message "[TESTCASE]- Verify Data Status On Disk..."
    verify_data_ondisk
    check_success "Data Encryption Verification on Disk"

    log_message "Check Replication Status before running pgbench..."
    verify_replication_status

    log_message "[TESTCASE]- Verify PgBench testcases..."
    pgbench_test_suite
    check_success "PgBench Testcases"

    log_message "[TESTCASE]- Verify Replica is down in replication..."
    verify_replica_failure
    check_success "Replica Failure Test"

    log_message "[TESTCASE]- Verify insert large dataset during replication..."
    verify_large_insert
    check_success "Large Data Insertion Test"

    #verify_standby_promotion $MASTER_PORT $STANDBY1_PORT $STANDBY1_DATA
    #check_success "Standby Promotion Test"
    #promote_standby
    #pg_rewind_master

    summarize_results
}

# Run All Tests
run_tests
