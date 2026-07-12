#!/bin/bash
set -e

DB_USER="${DB_USER:-adempiere}"
DB_PASS="${DB_PASS:-adempiere}"
DB_NAME="${DB_NAME:-idempiere}"
DB_PORT="${DB_PORT:-5433}"
CONTAINER_NAME="${CONTAINER_NAME:-idempiere-pg}"
PG_VERSION="${PG_VERSION:-16}"

if ! command -v docker &>/dev/null; then
    echo "Docker no está instalado. Instálalo primero."
    exit 1
fi

container_exists_running() {
    docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

container_exists_stopped() {
    docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

wait_for_pg() {
    echo "Esperando a que PostgreSQL esté listo..."
    for i in $(seq 1 30); do
        if docker exec "$CONTAINER_NAME" pg_isready -U "$DB_USER" &>/dev/null; then
            return 0
        fi
        sleep 1
    done
    echo "Error: PostgreSQL no se inició a tiempo."
    exit 1
}

ensure_postgres_role() {
    if ! docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres -tAc \
        "SELECT 1 FROM pg_roles WHERE rolname='postgres'" 2>/dev/null | grep -q 1; then
        echo "Creando rol 'postgres' (para compatibilidad con instalador)..."
        docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres \
            -c "CREATE ROLE postgres WITH LOGIN SUPERUSER PASSWORD '$DB_PASS'"
    fi
}

db_exists() {
    docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" 2>/dev/null | grep -q 1
}

create_db() {
    echo "Creando base de datos '$DB_NAME'..."
    docker exec "$CONTAINER_NAME" createdb -U "$DB_USER" -T template0 -E UNICODE "$DB_NAME"
}

print_info() {
    echo ""
    echo "=== Conexión para iDempiere ==="
    echo "  Host: localhost"
    echo "  Puerto: $DB_PORT"
    echo "  Base de datos: $DB_NAME"
    echo "  Usuario: $DB_USER"
    echo "  Contraseña: $DB_PASS"
    echo "  JDBC URL: jdbc:postgresql://localhost:$DB_PORT/$DB_NAME"
    echo ""
    echo "Ahora ejecuta la run configuration 'Install' en IntelliJ IDEA"
    echo "y usa esos datos de conexión."
}

# --- Flujo principal ---

if container_exists_running; then
    echo "Contenedor '$CONTAINER_NAME' ya está corriendo."
    ensure_postgres_role
    if db_exists; then
        echo "La base de datos '$DB_NAME' ya existe."
        print_info
        exit 0
    fi
    create_db
    print_info
    exit 0
fi

if container_exists_stopped; then
    echo "Contenedor '$CONTAINER_NAME' detenido. Iniciando..."
    docker start "$CONTAINER_NAME"
    wait_for_pg
    ensure_postgres_role
    if db_exists; then
        echo "La base de datos '$DB_NAME' ya existe."
    else
        create_db
    fi
    print_info
    exit 0
fi

echo "Creando contenedor PostgreSQL ${PG_VERSION} con base '$DB_NAME'..."
docker run -d \
    --name "$CONTAINER_NAME" \
    -e POSTGRES_USER="$DB_USER" \
    -e POSTGRES_PASSWORD="$DB_PASS" \
    -e POSTGRES_DB="$DB_NAME" \
    -p "$DB_PORT":5432 \
    postgres:"$PG_VERSION"

wait_for_pg
ensure_postgres_role
print_info
