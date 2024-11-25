#!/bin/bash
version="1.0.0"
set -euo pipefail
scriptName=`basename "$0"`

source $HOME/DellDPS-PaaS-Backup/common/functions.sh    # bash functions

# Database connection variables
DB_USER="dci"
# Decrypt and display in the terminal
check_file_exists db_password.enc
DB_PASSWORD=$(openssl enc -aes-256-cbc -d -salt -pbkdf2 -in db_password.enc -pass pass:my_secret_key)
DB_NAME="aidb"
DB_CONTAINER="syslogdb"
HOSTNAME=$(hostname --long)
LOGFILE="/tmp/syslogLoader.log"

delete_file /tmp/*.blobfuse2.sql
delete_file /tmp/*.blobfuse2.log

runtime=$(check_container_runtime)
header $version $scriptName; colors

# Function to insert a syslog entry into PostgreSQL
log_syslog_entry() {
	local HOSTNAME=$1
	local container=$2
    local raw_timestamp=$3
    local host=$4
    local facility=$5
    local severity=$6
    local message=$7

    # Add the current year to the raw timestamp and convert it to PostgreSQL-compatible format
    local formatted_timestamp=$(date -d "$raw_timestamp $(date +%Y)" "+%Y-%m-%d %H:%M:%S")

    # SQL INSERT statement
    sql="INSERT INTO syslog_entries (hostname, container, timestamp, host, facility, severity, message) VALUES ('$HOSTNAME', '$container', '$formatted_timestamp', '$host', '$facility', '$severity', '$message');"
    echo $sql >> $INSERT_FILE

}

# Process syslog file and insert each entry
syslog_parse() {
	local HOSTNAME=$1
	local container=$2
	local SYSLOG_FILE=$3
	log_message "($container) Process syslog file and insert each entry" "$LOGFILE"
	cat "$SYSLOG_FILE" | while read -r line; do

		# Example syslog format: "Oct 31 10:32:03 myhost kernel: [123456.789] sample syslog message"

		# Parse syslog line (customize parsing depending on syslog format)
		timestamp=$(echo "$line" | awk '{print $1" "$2" "$3}')
		host=$(echo "$line" | awk '{print $4}')
		facility=$(echo "$line" | awk '{print $6}')
		severity=$(echo "$line" | awk '{print $7}')
		message=$(echo "$line" | awk '{for(i=8;i<=15;i++) printf $i" "; print ""}')

		# Log entry to PostgreSQL
		log_syslog_entry "$HOSTNAME" "$container" "$timestamp" "$host" "$facility" "$severity" "$message"

	done

    [ ! -s $INSERT_FILE ] || log_message "($container) Execute the SQL command inside the PostgreSQL container" "$LOGFILE"; $runtime cp $INSERT_FILE $DB_CONTAINER:$INSERT_FILE
}

containers=$($runtime ps -a --format "{{.Names}}" | grep -v $DB_CONTAINER)
for container in $containers
do
	
	container_status=$(check_container_status $container)
	if [ $container_status = "running" ]; then
		log_message "Container $container is running" "$LOGFILE"
		# Define syslog file location
		SYSLOG_FILE="/tmp/$HOSTNAME.$container.blobfuse2.log"  
		INSERT_FILE="/tmp/$HOSTNAME.$container.blobfuse2.sql"  
		$runtime exec -it "$container" bash -c 'if [ -f /var/log/blobfuse2.log ]; then cp -f /var/log/blobfuse2.log /tmp/blobfuse2.log; fi'
		$runtime cp $container:/tmp/blobfuse2.log "$SYSLOG_FILE"
		[ ! -s $SYSLOG_FILE ] || syslog_parse $HOSTNAME $container $SYSLOG_FILE
	else
		log_message "Container $container is not running" "$LOGFILE"
	fi

done

if [ $(ls -1 /tmp/*.blobfuse2.sql 2>/dev/null | wc -l) -gt 0 ]; then
	container_status=$(check_container_status $DB_CONTAINER)
	if [ $container_status = "running" ]; then
		log_message "DB container $DB_CONTAINER is running" "$LOGFILE"
		for file in `ls -1 /tmp/*.blobfuse2.sql`
		do
			[ ! -s $file ] || $runtime exec -i $DB_CONTAINER psql -q -U $DB_USER -d $DB_NAME -f $file
		done
	else
		log_message "DB container $DB_CONTAINER is not running. Unable to load syslogs" "$LOGFILE"
	fi
fi

delete_file /tmp/*.blobfuse2.sql
delete_file /tmp/*.blobfuse2.log

footer $version $scriptName