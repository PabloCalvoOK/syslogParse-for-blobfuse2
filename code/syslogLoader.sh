#!/bin/bash
# Function to parse syslog entries and insert into PostgreSQL
version="1.0.0"
set -euo pipefail
scriptName=`basename "$0"`

source $HOME/DellDPS-PaaS-Backup/common/functions.sh    # bash functions

check_file_exists db_password.enc
parse_config syslog.ini

delete_file /tmp/*.blobfuse2.sql
delete_file /tmp/*.blobfuse2.log

runtime=$(check_container_runtime)
header $version $scriptName; colors

# Function to insert a syslog entry into PostgreSQL
log_syslog_entry() {
	local HOSTNAME=$1
	local db_container=$2
    local raw_timestamp=$3
    local host=$4
    local facility=$5
    local severity=$6
    local message=$7

    # Add the current year to the raw timestamp and convert it to PostgreSQL-compatible format
    local formatted_timestamp=$(date -d "$raw_timestamp $(date +%Y)" "+%Y-%m-%d %H:%M:%S")

    # SQL INSERT statement
    sql="INSERT INTO syslog_entries (hostname, container, timestamp, host, facility, severity, message) VALUES ('$HOSTNAME', '$db_container', '$formatted_timestamp', '$host', '$facility', '$severity', '$message');"
    echo $sql >> $INSERT_FILE

}

# Process syslog file and insert each entry
syslog_parse() {
	local HOSTNAME=$1
	local db_container=$2
	local SYSLOG_FILE=$3
	log_message "($db_container) Process syslog file and insert each entry" "$logfile"
	cat "$SYSLOG_FILE" | while read -r line; do

		# Example syslog format: "Oct 31 10:32:03 myhost kernel: [123456.789] sample syslog message"

		# Parse syslog line (customize parsing depending on syslog format)
		timestamp=$(echo "$line" | awk '{print $1" "$2" "$3}')
		host=$(echo "$line" | awk '{print $4}')
		facility=$(echo "$line" | awk '{print $6}')
		severity=$(echo "$line" | awk '{print $7}')
		message=$(echo "$line" | awk '{for(i=8;i<=15;i++) printf $i" "; print ""}')

		# Log entry to PostgreSQL
		log_syslog_entry "$HOSTNAME" "$db_container" "$timestamp" "$host" "$facility" "$severity" "$message"

	done

    [ ! -s $INSERT_FILE ] || log_message "($db_container) Execute the SQL command inside the PostgreSQL container" "$logfile"; $runtime cp $INSERT_FILE $db_container:$INSERT_FILE
}


blobfuseContainers=$($runtime ps -a --format "{{.Names}}" | grep -v $db_container | grep -v $app_container)
for blobfuseContainer in $blobfuseContainers
do
	
	container_status=$(check_container_status $blobfuseContainer)
	if [ $container_status = "running" ]; then
		log_message "Container $blobfuseContainer is running" "$logfile"
		# Define syslog file location
		SYSLOG_FILE="/tmp/$HOSTNAME.$blobfuseContainer.blobfuse2.log"  
		INSERT_FILE="/tmp/$HOSTNAME.$blobfuseContainer.blobfuse2.sql"  
		$runtime exec -it "$blobfuseContainer" bash -c 'if [ -f /var/log/blobfuse2.log ]; then cp -f /var/log/blobfuse2.log /tmp/blobfuse2.log; fi'
		$runtime cp $blobfuseContainer:/tmp/blobfuse2.log "$SYSLOG_FILE"
		if [ ! -s "$SYSLOG_FILE" ]; then
  			echo "Syslog file is empty or missing."
		else
 		 	syslog_parse "$HOSTNAME" "$blobfuseContainer" "$SYSLOG_FILE"
		fi
	else
		log_message "Container $blobfuseContainer is not running" "$logfile"
	fi

done

if [ $(ls -1 /tmp/*.blobfuse2.sql 2>/dev/null | wc -l) -gt 0 ]; then
	container_status=$(check_container_status $db_container)
	if [ $container_status = "running" ]; then
		log_message "DB container $db_container is running" "$logfile"
		for file in `ls -1 /tmp/*.blobfuse2.sql`
		do
			[ ! -s $file ] || cat $file | $runtime exec -i $db_container psql -q -U $user -d $dbname 
		done
	else
		log_message "DB container $db_container is not running. Unable to load syslogs" "$logfile"
	fi
fi

delete_file /tmp/*.blobfuse2.sql
delete_file /tmp/*.blobfuse2.log

footer $version $scriptName