#!/bin/bash
# # Creates syslog containers for the application.
# This section of the script is responsible for creating the necessary containers
# for the syslog functionality of the application, including the database container
# and the application container.
Create syslog containers
version="1.0.0"
set -euo pipefail
scriptName=`basename "$0"`

source $HOME/DellDPS-PaaS-Backup/common/functions.sh    # bash functions

# Variables
check_file_exists db_password.enc
parse_config syslog.ini

# Main script execution
runtime=$(check_container_runtime)

log_message "Creating $db_container container" "$logfile"

check_container ${db_container} ${runtime}
pull_image ${db_from_image} ${runtime}  
DB_PASSWORD=$(openssl enc -aes-256-cbc -d -salt -pbkdf2 -in db_password.enc -pass pass:my_secret_key)   

run_container ${db_container} ${db_from_image} ${user} ${DB_PASSWORD} ${dbname} ${port} ${runtime}git 

while true; do
    container_status=$(check_container_status $db_container)
    if [ $container_status = "running" ]; then
        seconds=10
        log_message "Sleeping $seconds seconds to wait for DB $dbname creation (container name: $db_container)" "$logfile"
        sleep $seconds 
        log_message "Creating table syslog_entries in DB $dbname (container name: $db_container)" "$logfile"
        if ! $runtime exec -it $db_container psql -U ${user} -d ${dbname} \
            -c "CREATE TABLE IF NOT EXISTS syslog_entries (id SERIAL PRIMARY KEY, hostname TEXT, container TEXT, timestamp TIMESTAMP, host TEXT, facility TEXT, severity TEXT, message TEXT);" ; then
            echo "Error: Failed to create table syslog_entries in DB $dbname in container'$db_container'."
            exit 1
        else
            log_message "Sucess: Created table syslog_entries in DB $dbname (container name: $db_container)" "$logfile"
            break
        fi
    else
        sleep 5
    fi
done

log_message "Creating $app_container container" "$logfile"

container_status=$(check_container_status $db_container)
if [ $container_status = "running" ]; then db_container_ip=$(podman inspect ${db_container} --format "{{.NetworkSettings.Networks.${container_network}.IPAddress}}"); fi

# Chequear network

check_parameter $db_container_ip

sed -i "s/^container_ip = .*/container_ip = $db_container_ip/" syslog.ini
$runtime build -t ${app_container} --build-arg BASE_IMAGE=${app_from_image} -f syslog_visualize.dockerfile
$runtime run --name ${app_container} --hostname  ${app_container} -d -it --network ${container_network} ${app_container}:latest /bin/bash

container_status=$(check_container_status $app_container)
if [ $container_status = "running" ]; then echo "Container $app_container is up & running"; fi