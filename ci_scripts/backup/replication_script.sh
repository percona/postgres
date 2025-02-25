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
        ((TESTS_FAILED++))
        return 1
    fi

    # Ensure actual output file exists
    if [ ! -f "$actual_file" ]; then
        log_message "❌ Actual output file missing: $actual_file"
        ((TESTS_FAILED++))
        return 1
    fi

    # Remove old diff file if exists
    [ -f "$diff_file" ] && rm -f "$diff_file"

    # Compare files
    if diff -q "$expected_file" "$actual_file" > /dev/null; then
        log_message "✅ Output matches expected result."
        ((TESTS_PASSED++))
    else
        diff "$expected_file" "$actual_file" > "$diff_file"
        log_message "❌ Output mismatch. See diff file: $diff_file"
        ((TESTS_FAILED++))
    fi
}

# Function to configure the primary PostgreSQL server
configure_primary_server() {
    log_message "Configuring Primary PostgreSQL Server..."

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
    pg_ctl -D "$MASTER_DATA" -l "$INSTALL_DIR/master.log" -o "-p ${MASTER_PORT}" restart >> $LOGFILE 2>&1

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
    local standby_log="$standby_data/standby.log"

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
    sleep 5

    # Verify that the standby is running and connected to the primary
    psql -h "localhost" -p "$standby_port" -d postgres -c "SELECT pg_is_in_recovery();" | grep -q "t"
    if [ $? -eq 0 ]; then
       log_message "✅ Standby Server is in Recovery Mode (Replication Active)"
        ((TESTS_PASSED++))
    else
        log_message "❌ Standby Server is NOT in recovery mode! Replication may have failed."
        ((TESTS_FAILED++))
    fi
}
insert_data(){
    local sql_file="${1:-sampe_data.sql}"
    local db_name="${2:-$DB_NAME}"
    local port="${3:-$MASTER_PORT}"

    psql -p "$port" -d "$db_name" -f "$SQL_DIR/$sql_file" >> "$LOGFILE" 2>&1
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
        ((TESTS_FAILED++))
    else
        log_message "✅ Data appears to be ENCRYPTED!"
        ((TESTS_PASSED++))
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
    sync && sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
    log_message "Running pgbench with $CLIENTS clients and $THREADS threads for $DURATION seconds..."
    pgbench -T $DURATION -c $CLIENTS -j $THREADS -M prepared -d $DB_NAME -p $MASTER_PORT >> $LOGFILE 2>&1
    if [ $? -eq 0 ]; then
        log_message "✅ Pgbench Run Completed..."
    else
        log_message "❌ Pgbench Run failed..."
    fi
}

# Check replication lag before and after running pgbench
check_replication_lag() {
    log_message "🔍 Checking Replication Lag on Master..."
    psql -p "$MASTER_PORT" -d "$DB_NAME" -c "SELECT * FROM pg_stat_replication;" >> "$LOGFILE" 2>&1
    if [ $? -eq 0 ]; then
        log_message "✅ Replication Lag Check passed on Master..."
        ((TESTS_PASSED++))
    else
        log_message "❌ Replication Lag Check failed on Master..."
        ((TESTS_FAILED++))
    fi
}
check_replication_wal_stats() {
    log_message "🔍 Checking WAL Statistics on Master..."
    psql -p "$MASTER_PORT" -d "$DB_NAME" -c "SELECT * FROM pg_stat_wal;" >> "$LOGFILE" 2>&1

    if [ $? -eq 0 ]; then
        log_message "✅ Replication WAL Statistics Passed on Master..."
        ((TESTS_PASSED++))
    else
        log_message "❌ Replication WAL Statistics Failed on Master..."
        ((TESTS_FAILED++))
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
    grep -Ei 'replication|error|fatal|wal' "$log_file" | tail -20 | tee -a "$LOGFILE" > "$temp_log"

    # Check if errors exist in extracted logs
    if grep -Ei 'fatal|error' "$temp_log"; then
        log_message "❌ Errors detected in PostgreSQL logs! Check $log_file for details."
        ((TESTS_FAILED++))
    else
        log_message "✅ No Error message in Server log: ($port)"
        ((TESTS_PASSED++))
    fi

    # Clean up temporary file
    rm -f "$temp_log"
}

# Function to run the pgbench test suite
pgbench_test_suite() {
    echo "=== 🚀 Running pgbench Replication Tests ====" |tee -a $LOGFILE

    # Check replication lag before running pgbench
    check_replication_lag

    # Check WAL statistics before running pgbench
    check_replication_wal_stats

    # Initialize pgbench on the master node
    initialize_pgbench

    # Run pgbench on the master node
    run_pgbench

    # Check replication lag after running pgbench
    check_replication_lag

    # Check WAL statistics after running pgbench
    check_replication_wal_stats

    # Verify that pgbench data was replicated correctly
    #pgbench_verification
    verify_database_data verify_pgbench_data.sql

    # Verify log files on master node for errors
    analyze_logs $MASTER_PORT
    # Verify log files on master node for errors
    analyze_logs $STANDBY1_PORT
    # Verify log files on master node for errors
    analyze_logs $STANDBY2_PORT

    echo "== 🚀 Pgbench Tests completed==" |tee -a $LOGFILE
}

# Function to promote the standby node to master
promote_standby() {
    local standby_data=$1
    local standby_log=$standby_data/standby.log
    pg_ctl -D $standby_data promote -l $standby_log
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
    configure_standby $STANDBY1_DATA $STANDBY1_PORT
    configure_standby $STANDBY2_DATA $STANDBY2_PORT
    verify_database_data verify_sample_data.sql
    insert_data incremental_data.sql $DB_NAME $MASTER_PORT
    verify_database_data verify_incremental_data.sql
    verify_data_ondisk
    pgbench_test_suite
    #promote_standby
    #pg_rewind_master

    summarize_results
}

# Run All Tests
run_tests
