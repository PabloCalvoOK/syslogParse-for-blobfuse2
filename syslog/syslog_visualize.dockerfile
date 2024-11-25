# podman build -t syslog_visualize -f syslog_visualize.dockerfile
FROM almalinux:latest

RUN dnf -y update && \
    dnf -y install systemd && \
    dnf -y install pip && \
    dnf clean all
# Create a directory for systemd runtime
VOLUME [ "/sys/fs/cgroup" ]

# Install dependencies
RUN pip install psycopg2-binary
# Install app modules
RUN pip install psycopg2-binary pandas scikit-learn sqlalchemy matplotlib

# Copy the Python scripts
COPY testConnection.py /app/testConnection.py
COPY syslogAnalysis.py /app/syslogAnalysis.py

WORKDIR /app

# Command to run the script
CMD ["python", "connect_postgresql.py"]

# Start systemd as the default entrypoint
ENTRYPOINT ["/usr/lib/systemd/systemd"]
