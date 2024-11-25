Use this command to create an file with your incrypted password

```
echo -n "<your_password>" | openssl enc -aes-256-cbc -salt -pbkdf2 -out db_password.enc -pass pass:my_secret_key
```

Internal network creation

```
podman network create mynetwork
``` 
How to build the syslog_visualize image and run the container
```
podman build -t syslog_visualize -f syslog_visualize.dockerfile
podman run --name syslog_visualize --hostname  syslog_visualize -d -it --network  syslog_visualize:latest /bin/bash
```

If syslogdb and syslog_visualize are not connected to mynetwork
```
podman network connect mynetwork syslogdb
podman network connect mynetwork syslog_visualize
```



