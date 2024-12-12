#
ARG BASE_IMAGE=centos:latest

FROM ${BASE_IMAGE}

RUN dnf -y update && \
    dnf -y install systemd && \
    dnf -y install pip && \
    dnf clean all
# Create a directory for systemd runtime
VOLUME [ "/sys/fs/cgroup" ]

# Install app modules
RUN pip install psycopg2-binary pandas scikit-learn sqlalchemy matplotlib cryptography

# Create the working directory (optional)
WORKDIR /app

COPY syslogAnalysis.py /app/syslogAnalysis.py
# Copy config and password file
COPY syslog.ini /app/syslog.ini
COPY db_password.enc /app/db_password.enc

# Command to run the script
CMD ["python", "syslogAnalysis.py"]

# Start systemd as the default entrypoint
ENTRYPOINT ["/usr/lib/systemd/systemd"]
