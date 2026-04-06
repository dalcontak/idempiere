#!/usr/bin/env bash
# =============================================================================
# iDempiere Docker Entrypoint (ARM64)
# Adapted from https://github.com/idempiere/idempiere-docker
# =============================================================================
set -Eeo pipefail

echo "============================================="
echo " iDempiere ERP - ARM64 Docker Container"
echo "============================================="

# ---------------------------------------------------------------------------
# Default environment variables
# ---------------------------------------------------------------------------
JAVA_OPTIONS=${JAVA_OPTIONS:-}
KEY_STORE_PASS=${KEY_STORE_PASS:-myPassword}
KEY_STORE_ON=${KEY_STORE_ON:-idempiere.org}
KEY_STORE_OU=${KEY_STORE_OU:-iDempiere Docker}
KEY_STORE_O=${KEY_STORE_O:-iDempiere}
KEY_STORE_L=${KEY_STORE_L:-myTown}
KEY_STORE_S=${KEY_STORE_S:-CA}
KEY_STORE_C=${KEY_STORE_C:-US}
HOST=${HOST:-0.0.0.0}
IDEMPIERE_PORT=${IDEMPIERE_PORT:-8080}
IDEMPIERE_SSL_PORT=${IDEMPIERE_SSL_PORT:-8443}
TELNET_PORT=${TELNET_PORT:-12612}
DB_HOST=${DB_HOST:-postgres}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-idempiere}
DB_USER=${DB_USER:-adempiere}
DB_PASS=${DB_PASS:-adempiere}
DB_ADMIN_PASS=${DB_ADMIN_PASS:-postgres}
MAIL_HOST=${MAIL_HOST:-0.0.0.0}
MAIL_USER=${MAIL_USER:-info}
MAIL_PASS=${MAIL_PASS:-info}
MAIL_ADMIN=${MAIL_ADMIN:-info@idempiere}
MIGRATE_EXISTING_DATABASE=${MIGRATE_EXISTING_DATABASE:-false}

# ---------------------------------------------------------------------------
# Docker secrets support (_FILE suffix)
# ---------------------------------------------------------------------------
if [[ -n "$DB_PASS_FILE" ]]; then
    echo "Reading DB_PASS from secret file..."
    DB_PASS=$(cat "$DB_PASS_FILE")
fi

if [[ -n "$DB_ADMIN_PASS_FILE" ]]; then
    echo "Reading DB_ADMIN_PASS from secret file..."
    DB_ADMIN_PASS=$(cat "$DB_ADMIN_PASS_FILE")
fi

if [[ -n "$MAIL_PASS_FILE" ]]; then
    echo "Reading MAIL_PASS from secret file..."
    MAIL_PASS=$(cat "$MAIL_PASS_FILE")
fi

if [[ -n "$KEY_STORE_PASS_FILE" ]]; then
    echo "Reading KEY_STORE_PASS from secret file..."
    KEY_STORE_PASS=$(cat "$KEY_STORE_PASS_FILE")
fi

# ---------------------------------------------------------------------------
# Main: iDempiere startup
# ---------------------------------------------------------------------------
if [[ "$1" == "idempiere" ]]; then
    # Wait for PostgreSQL
    RETRIES=${DB_WAIT_RETRIES:-30}
    echo "Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."
    until PGPASSWORD="$DB_ADMIN_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -c "\q" > /dev/null 2>&1 || [[ $RETRIES == 0 ]]; do
        echo "  Waiting... $((RETRIES--)) attempts remaining"
        sleep 2
    done

    if [[ $RETRIES == 0 ]]; then
        echo "ERROR: Could not connect to PostgreSQL. Shutting down."
        exit 1
    fi
    echo "PostgreSQL is ready."

    # Run console-setup to generate configs from environment
    echo "Generating configuration..."
    rm -f idempiereEnv.properties jettyhome/etc/keystore

    if [[ -f "./console-setup-alt.sh" ]]; then
        echo -e "$JAVA_HOME\n$JAVA_OPTIONS\n$IDEMPIERE_HOME\n$KEY_STORE_PASS\n$KEY_STORE_ON\n$KEY_STORE_OU\n$KEY_STORE_O\n$KEY_STORE_L\n$KEY_STORE_S\n$KEY_STORE_C\n$HOST\n$IDEMPIERE_PORT\n$IDEMPIERE_SSL_PORT\nN\n2\n$DB_HOST\n$DB_PORT\n$DB_NAME\n$DB_USER\n$DB_PASS\n$DB_ADMIN_PASS\n$MAIL_HOST\n$MAIL_USER\n$MAIL_PASS\n$MAIL_ADMIN\nY\n" | ./console-setup-alt.sh
    else
        echo -e "$JAVA_HOME\n$JAVA_OPTIONS\n$IDEMPIERE_HOME\n$KEY_STORE_PASS\n$KEY_STORE_ON\n$KEY_STORE_OU\n$KEY_STORE_O\n$KEY_STORE_L\n$KEY_STORE_S\n$KEY_STORE_C\n$HOST\n$IDEMPIERE_PORT\n$IDEMPIERE_SSL_PORT\nN\n2\n$DB_HOST\n$DB_PORT\n$DB_NAME\n$DB_USER\n$DB_PASS\n$DB_ADMIN_PASS\n$MAIL_HOST\n$MAIL_USER\n$MAIL_PASS\n$MAIL_ADMIN\nY\n" | ./console-setup.sh
    fi

    # Database initialization or migration
    if ! PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "\q" > /dev/null 2>&1; then
        echo "Database '$DB_NAME' not found. Importing seed..."
        cd utils
        ./RUN_ImportIdempiere.sh
        echo "Synchronizing database..."
        ./RUN_SyncDB.sh
        cd ..
        echo "Signing database..."
        ./sign-database-build.sh
    else
        echo "Database '$DB_NAME' exists."
        if [[ "$MIGRATE_EXISTING_DATABASE" == "true" ]]; then
            echo "MIGRATE_EXISTING_DATABASE=true. Running sync..."
            cd utils
            ./RUN_SyncDB.sh
            cd ..
            echo "Signing database..."
            ./sign-database-build.sh
        else
            echo "Skipping migration (MIGRATE_EXISTING_DATABASE=false)."
        fi
    fi
fi

echo "Starting iDempiere..."
exec "$@"
