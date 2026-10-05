#!/usr/bin/env bash

set -Eeuo pipefail

PG_VERSION="16"
PG_DATA="/var/lib/postgresql/${PG_VERSION}/main"
PG_BIN="/usr/lib/postgresql/${PG_VERSION}/bin"
PG_CONFIG="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"

echo "Preparing PostgreSQL..."

mkdir -p "$PG_DATA"
mkdir -p /run/postgresql
mkdir -p /var/log/supervisor

chown -R postgres:postgres /var/lib/postgresql
chown postgres:postgres /run/postgresql

# При первом запуске Docker Volume пустой,
# поэтому инициализируем PostgreSQL cluster
if [[ ! -f "$PG_DATA/PG_VERSION" ]]; then
    echo "Initializing PostgreSQL database cluster..."

    runuser -u postgres -- \
        "$PG_BIN/initdb" \
        -D "$PG_DATA"

    echo "PostgreSQL cluster initialized."
fi

# Временно запускаем PostgreSQL для первоначальной настройки
runuser -u postgres -- \
    "$PG_BIN/pg_ctl" \
    -D "$PG_DATA" \
    -o "-c config_file=$PG_CONFIG" \
    -l /tmp/postgresql-init.log \
    start

echo "Waiting for PostgreSQL..."

until runuser -u postgres -- pg_isready >/dev/null 2>&1; do
    sleep 1
done

echo "PostgreSQL is ready."

# Создание пользователя PostgreSQL
if ! runuser -u postgres -- psql -tAc \
    "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1; then

    runuser -u postgres -- psql -c \
        "CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASSWORD}';"

    echo "Database user ${DB_USER} created."
else
    echo "Database user ${DB_USER} already exists."
fi

# Создание базы данных
if ! runuser -u postgres -- psql -tAc \
    "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then

    runuser -u postgres -- createdb \
        -O "${DB_USER}" \
        "${DB_NAME}"

    echo "Database ${DB_NAME} created."
else
    echo "Database ${DB_NAME} already exists."
fi

echo "Database initialization completed."

# Останавливаем временно запущенный PostgreSQL
runuser -u postgres -- \
    "$PG_BIN/pg_ctl" \
    -D "$PG_DATA" \
    stop

echo "Starting Nginx and PostgreSQL..."

# Запускаем оба процесса через Supervisor
exec /usr/bin/supervisord \
    -c /etc/supervisor/conf.d/supervisord.conf