FROM debian:bullseye

# Install PostgreSQL and dependencies
RUN apt-get update && apt-get install -y \
    postgresql-13 \
    postgresql-contrib-13 \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create PostgreSQL data directory
RUN mkdir -p /var/lib/postgresql/13/main && \
    chown -R postgres:postgres /var/lib/postgresql && \
    chmod 700 /var/lib/postgresql/13/main

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose PostgreSQL port
EXPOSE 5432

# Run entrypoint script as root (will switch to postgres for server)
ENTRYPOINT ["/entrypoint.sh"]
