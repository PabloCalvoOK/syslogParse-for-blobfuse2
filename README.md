## Scripts to automate the Avamar Root-to-Root Replication.

![License](https://img.shields.io/badge/license-MIT-green)
![Version](https://img.shields.io/badge/version-1.0.0-blue)

## Table of Contents

- [Introduction](#introduction)
- [Features](#features)
- [Getting Started](#getting-started)
  - [Installation](#installation)
  - [Usage](#usage)
- [Contributing and License](#contributing-and-license)
- [Contact](#contact)

## Introduction


## Features



#### Disclaimer



# Getting Started

### Installation

**Clone the Repository**

  ```
   git clone https://github.com/<repository_owner>/syslogParse-for-blobfuse2.git
   cd R2R
  ```

### Usage

0.- Configure syslog.ini

```
[database]
container = <db_container>
# container_ip is added dinamically
container_ip = <db_container_ip>
from_image = <db_from_image> # Example postgres:latest
user = <user>
dbname = <dbname>
port = <port>
logfile = <logfile>

[vizualize]
container = <app_container>
from_image = <app_from_image> # Example almalinux:latest
container_network = <container_network>
```

1.- Use this command to create an file with your incrypted password

```
echo -n "<your_password>" | openssl enc -aes-256-cbc -salt -pbkdf2 -out db_password.enc -pass pass:my_secret_key
```
    
2.- Run **syslogDBCreation.sh** to create the db and app containers

3.- Run **syslogLoader.sh** to load syslog to db container from Blobfuse2 containers

4.- Run **syslogAnalysis.py**
    
   podman|docker exec -it <app_container> /bin/bash
   [root@syslog_visualize app]# python3 syslogAnalysis.py

This script plots a error graph in the file /app/severity_plot.png.

A.- Internal network creation

```
podman network create <container_network>
``` 

B.- If <db_container> and <app_container> are not connected to <container_network>

```
podman network connect <container_network> <db_container>
podman network connect <container_network> <app_container>
```

## Contributing and License

We welcome contributions! Please see our [CONTRIBUTING.md](CONTRIBUTING.md) file for details on our code of conduct, and the process for submitting pull requests. This project is licensed under the MIT [LICENSE](LICENSE).