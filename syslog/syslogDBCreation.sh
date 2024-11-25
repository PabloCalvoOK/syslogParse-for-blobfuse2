#!/bin/bash
version="1.0.0"
set -euo pipefail
scriptName=`basename "$0"`

source $HOME/DellDPS-PaaS-Backup/common/functions.sh    # bash functions

# Variables
DB_CONTAINER="syslogdb"
IMAGE_NAME="postgres:latest"
DB_USER="dci"
check_file_exists db_password.enc
#DB_PASSWORD=$(openssl enc -aes-256-cbc -d -salt -pbkdf2 -in db_password.enc -pass pass:my_secret_key)
DB_PASSWORD="*julian2024*" 
DB_NAME="aidb"
PORT="5432"
LOGFILE="/tmp/syslogLoader.log"



# Main script execution
runtime=$(check_container_runtime)
check_container ${DB_CONTAINER} ${runtime}
pull_image ${IMAGE_NAME} ${runtime}     
run_container ${DB_CONTAINER}  ${IMAGE_NAME} ${DB_USER} ${DB_PASSWORD} ${DB_NAME} ${PORT} ${runtime}

while true; do
    container_status=$(check_container_status $DB_CONTAINER)
    if [ $container_status = "running" ]; then
        seconds=10
        log_message "Sleeping $seconds seconds to wait for DB $DB_NAME creation (container name: $DB_CONTAINER)" "$LOGFILE"
        sleep $seconds 
        log_message "Creating table syslog_entries in DB $DB_NAME (container name: $DB_CONTAINER)" "$LOGFILE"
        if ! $runtime exec -it ${DB_CONTAINER} psql -U ${DB_USER} -d ${DB_NAME} \
            -c "CREATE TABLE IF NOT EXISTS syslog_entries (id SERIAL PRIMARY KEY, hostname TEXT, container TEXT, timestamp TIMESTAMP, host TEXT, facility TEXT, severity TEXT, message TEXT);" ; then
            echo "Error: Failed to create table syslog_entries in DB $DB_NAME in container'${DB_CONTAINER}'."
            exit 1
        else
            log_message "Sucess: Created table syslog_entries in DB $DB_NAME (container name: $DB_CONTAINER)" "$LOGFILE"
            break
        fi
    else
        sleep 5
    fi
done