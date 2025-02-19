#!/bin/bash
# This script is used to set up replication setup with TDE enabled
export TDE_MODE=1

SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"
INSTALL_DIR="$SCRIPT_DIR/../../pginst"
export PATH=$INSTALL_DIR/bin:$PATH

# Environment variables for PGDATA and archive directories
MASTER_DATA=$INSTALL_DIR/primary
STANDBY1_DATA=$INSTALL_DIR/standby1
STANDBY2_DATA=$INSTALL_DIR/standby2
ARCHIVE_DIR=$INSTALL_DIR/archive
SQL_DIR=$SCRIPT_DIR/backup/sql
MASTER_PORT=55433
STANDBY1_PORT=55434
STANDBY2_PORT=55435
DB_NAME=tde_db
EXPECTED_DIR=$SCRIPT_DIR/backup/expected
ACTUAL_DIR=$SCRIPT_DIR/actual
LOGFILE=$INSTALL_DIR/replication.log
TABLE_NAME="emp"
SEARCHED_TEXT="SMITH"

# Create directories for expected, actual, and archive files
mkdir -p $EXPECTED_DIR $ACTUAL_DIR $ARCHIVE_DIR

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" |tee -a "$LOGFILE"
}

# Function to run SQL files and capture results
run_sql() {
    local sql_file=$1
    local db_name="${2:-$DB_NAME}"
    local port="${3:-$MASTER_PORT}"
    local out_dir="${4:-$ACTUAL_DIR}"
    local file_name=$(basename "$sql_file" .sql)
    
    if [ ! -d "$out_dir" ]; then
        mkdir -p "$out_dir"
    fi

    if [ -f "$out_dir/$file_name.out" ]; then
        rm -fr "$out_dir/$file_name.out"
    fi
    psql -d $db_name -p $port -e -a -f "$SQL_DIR/$sql_file" > "$out_dir/$file_name.out" 2>&1
}

# Function to verify expected vs actual output
verify_output() {
    local sql_file=$1
    local actualdir=$2
    local file_name=$(basename "$sql_file" .sql)
    local expected_file="$EXPECTED_DIR/$file_name.out"
    local actual_file="$actualdir/$file_name.out"
    local diff_file="$actualdir/$file_name.diff"
    
    if [ -f $diff_file ]; then
        rm -fr $diff_file
    fi

    if diff -q "$expected_file" "$actual_file" > /dev/null; then
        log_message "$sql_file matches expected output. ✅"
    else
        log_message "$sql_file output mismatch. ❌"
        diff "$expected_file" "$actual_file" > $diff_file
	log_message "See diff file. $diff_file "
    fi
}

# Verify Data Encryption at Rest
verify_encrypted_data_at_rest() {
    local table_name="${1:-$TABLE_NAME}"
    local search_text="${2:-$SEARCHED_TEXT}"
    local pg_port="${3:-$MASTER_PORT}"
    local db_name="${4:-$DB_NAME}"
    # Get Data File Path
    pg_relation_filepath=$(psql -p $pg_port -d "$db_name" -t -c "SELECT pg_relation_filepath('$table_name');" | xargs)
    data_dir_path=$( psql -p $pg_port -d "$db_name" -t -c "SHOW data_directory" | xargs)
    file_name="$data_dir_path/$pg_relation_filepath"

    log_message "Verifying data encryption at rest for table: $table_name in database: $db_name on port: $pg_port"
    log_message "Data file path: $file_name"

    # Extract first 10 lines of raw data
    raw_data=$(sudo hexdump -C "$file_name" | head -n 10 || true)
    log_message "$raw_data"

    readable_text=$(sudo strings "$file_name" | grep "$search_text" || true)
    # Check if there is readable text in the data file
    if [[ -n "$readable_text" ]]; then
        log_message "Readable text detected! Data appears UNENCRYPTED.❌ "
    else
        log_message "Test Passed: Data appears to be encrypted! ✅ "
    fi
}

#======================================================
configure_primary_server(){
    # Create the primary server
    source $SCRIPT_DIR/configure-tde-server.sh  $MASTER_DATA $MASTER_PORT

    # Need to verify it with different configurations
    # Like wal_buffers, wal_writer_delay, wal_writer_flush_after, etc.
    # Basic configuration of PostgreSQL
    cat >> $MASTER_DATA/postgresql.conf <<EOF
    archive_command = 'rsync -a %p ${ARCHIVE_DIR}/%f'
    archive_mode = on
    wal_level = replica
    max_wal_senders = 10
    min_wal_size = '80MB'
    max_wal_size = '10GB'
    hot_standby = on
    wal_log_hints = on
    listen_addresses = '*'
EOF
    
    # Allow replication connections
    cat >> $MASTER_DATA/pg_hba.conf <<EOF
    # Trust local access for replication
    # BE CAREFUL WHEN DOING THIS IN PRODUCTION
    local replication replication trust
EOF

    # Restart the master
    pg_ctl -D $MASTER_DATA -l $INSTALL_DIR/master.log -o "-p ${MASTER_PORT}" restart

    # Create the replication user
    psql -p $MASTER_PORT -c "CREATE USER replication WITH replication"

    # Create tde_db database
    createdb -p $MASTER_PORT $DB_NAME
    psql -p $MASTER_PORT -d $DB_NAME -c "CREATE EXTENSION pg_tde"
    psql -p $MASTER_PORT -d $DB_NAME -c "SELECT pg_tde_set_default_principal_key('default-principal-key','reg_file-global',false)"

    # Create separate database for TDE functionality
    psql -p $MASTER_PORT -d $DB_NAME -f $SQL_DIR/sample_data.sql > /dev/null
}

#=====================================================
configure_standby() {
    local standby_data=$1
    local standby_port=$2
    local standby_log=$standby_data/standby.log

    # Make sure $standby_data is empty
    if [ -d "$standby_data" ]; then
        if pg_ctl -D "$standby_data" status -o "-p $standby_port" >/dev/null; then
            pg_ctl -D "$standby_data" stop -o "-p $standby_port"
        fi
        rm -rf "$standby_data"
    fi
    
    log_message "Creating pg_basebackup $standby_data..."
    pg_basebackup -D $standby_data -U replication -p $MASTER_PORT -Xs -R -P

    # Update the postgresql.conf file with the port $standby_port
    log_message "Updating $standby_data/postgresql.conf"
    cat >> $standby_data/postgresql.conf <<EOF
    port = ${standby_port}
EOF
    # Start the standby server $standby_data
    log_message "Starting $standby_data -l $standby_log ..."
    pg_ctl -D $standby_data -l $standby_log start
    sleep 5
}

data_verification() {
    # Verify the data on the standby1
    run_sql verify_sample_data.sql $DB_NAME $STANDBY1_PORT "${ACTUAL_DIR}/standby1"
    log_message "Verifying sample data on master and standby1"
    verify_output verify_sample_data.sql "${ACTUAL_DIR}/standby1"

    # Verify the data on the standby2
    run_sql verify_sample_data.sql $DB_NAME $STANDBY2_PORT "${ACTUAL_DIR}/standby2"
    log_message "Verifying sample data on master and standby2"
    verify_output verify_sample_data.sql "${ACTUAL_DIR}/standby2"

    # Add some more data after replication setup into the master
    psql -p $MASTER_PORT -d $DB_NAME -f $SQL_DIR/incremental_data.sql > /dev/null

    # Verify the data on the standby1
    run_sql verify_incremental_data.sql $DB_NAME $STANDBY1_PORT "${ACTUAL_DIR}/standby1"
    log_message "Verifying incremental data on master and standby1"
    verify_output verify_incremental_data.sql "${ACTUAL_DIR}/standby1"

    # Verify the data on the standby2
    run_sql verify_incremental_data.sql $DB_NAME $STANDBY2_PORT "${ACTUAL_DIR}/standby2"
    log_message "Verifying incremental data on master and standby2"
    verify_output verify_incremental_data.sql "${ACTUAL_DIR}/standby2"
}

verify_data_ondisk(){
    verify_encrypted_data_at_rest $TABLE_NAME $SEARCHED_TEXT $MASTER_PORT $DB_NAME
    verify_encrypted_data_at_rest $TABLE_NAME $SEARCHED_TEXT $STANDBY1_PORT $DB_NAME
    verify_encrypted_data_at_rest $TABLE_NAME $SEARCHED_TEXT $STANDBY2_PORT $DB_NAME
}

promote_standby() {
    local standby_data=$1
    local standby_log=$standby_data/standby.log
    pg_ctl -D $standby_data promote -l $standby_log
}

pg_rewind() {
    pg_rewind --target-pgdata=$MASTER_DATA --source-server="port=$STANDBY1_PORT user=postgres dbname=$DB_NAME"  > $ACTUAL_DIR/pg_rewind.log 2>&1
}
#======================================================
# Main Script Execution
main() {
    echo "=== Starting replication Test Automation ==="
    configure_primary_server
    configure_standby $STANDBY1_DATA $STANDBY1_PORT
    configure_standby $STANDBY2_DATA $STANDBY2_PORT
    data_verification
    verify_data_ondisk
    #promote_standby
    #pg_rewind
    echo "=== replication Test Automation Completed! === 🚀"
}

# Run Main Function
main

