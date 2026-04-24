#!/bin/bash

# PostgreSQL paths and settings
DATA_DIR="/var/lib/postgresql/13/main"
PG_BIN="/usr/lib/postgresql/13/bin"
PGCTL="$PG_BIN/pg_ctl"

# Step 1: Ensure parent directory exists and is owned by postgres
mkdir -p /var/lib/postgresql
chmod 755 /var/lib/postgresql
chown postgres:postgres /var/lib/postgresql

# Step 2: Create data directory with proper permissions BEFORE initdb
if [ ! -d "$DATA_DIR" ]; then
    mkdir -p "$DATA_DIR"
fi
chmod 700 "$DATA_DIR"
chown postgres:postgres "$DATA_DIR"

# Step 3: Initialize PostgreSQL cluster if needed
if [ ! -f "$DATA_DIR/PG_VERSION" ]; then
    echo "🔧 Initializing PostgreSQL cluster..."
    # Clean up any existing files first
    rm -rf "$DATA_DIR"/*
    runuser -u postgres -- $PG_BIN/initdb -D "$DATA_DIR" -A trust
    echo "✅ Cluster initialized"
fi

# Step 4: Ensure config file exists
if [ ! -f "$DATA_DIR/postgresql.conf" ]; then
    echo "⚠️  Config file missing, reinitializing..."
    rm -f "$DATA_DIR/PG_VERSION"
    rm -rf "$DATA_DIR"/*
    runuser -u postgres -- $PG_BIN/initdb -D "$DATA_DIR" -A trust
fi

# Step 5: Configure pg_hba.conf to allow Docker network connections
configure_hba() {
    HBA_FILE="$DATA_DIR/pg_hba.conf"
    echo "🔧 Configuring pg_hba.conf for network access..."
    
    # Check if docker network entry already exists
    if ! grep -q "172.18.0.0/16" "$HBA_FILE"; then
        # Add entry for Docker network before the existing entries
        echo "host    all             all             172.18.0.0/16          trust" >> "$HBA_FILE"
    fi
}

configure_hba

# Step 6: Create database and user (as postgres user)
create_db_and_user() {
    echo "🔑 Creating database and user..."
    
    # Start PostgreSQL temporarily
    runuser -u postgres -- $PGCTL -D "$DATA_DIR" -l /tmp/postgres.log start -w
    
    # Give it a moment to fully start
    sleep 2
    
    # Create user with login ability
    runuser -u postgres -- $PG_BIN/psql -d postgres -c "CREATE USER inventory_user WITH PASSWORD '${INVENTORY_DB_PASSWORD}';" 2>/dev/null || true
    
    # Create database owned by user
    runuser -u postgres -- $PG_BIN/psql -d postgres -c "CREATE DATABASE inventory_db OWNER inventory_user;" 2>/dev/null || true
    
    # Grant all privileges
    runuser -u postgres -- $PG_BIN/psql -d inventory_db -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO inventory_user;" 2>/dev/null || true
    runuser -u postgres -- $PG_BIN/psql -d inventory_db -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO inventory_user;" 2>/dev/null || true
    runuser -u postgres -- $PG_BIN/psql -d inventory_db -c "GRANT CREATE ON SCHEMA public TO inventory_user;" 2>/dev/null || true
    
    # Stop PostgreSQL
    runuser -u postgres -- $PGCTL -D "$DATA_DIR" stop -m fast
    
    echo "✅ Database and user created"
}

# Check if database already exists
DB_CHECK=$(runuser -u postgres -- $PGCTL -D "$DATA_DIR" status 2>/dev/null | grep "down" || echo "not_running")
if [ "$DB_CHECK" == "not_running" ] || [ ! -f "$DATA_DIR/inventory_db.initialized" ]; then
    create_db_and_user
    touch "$DATA_DIR/inventory_db.initialized"
fi

# Step 7: Start PostgreSQL as postgres user (foreground)
echo "🚀 Starting PostgreSQL on port 5432..."
exec runuser -u postgres -- $PG_BIN/postgres -D "$DATA_DIR" -h 0.0.0.0

