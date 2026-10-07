#!/usr/bin/env bash
set -Eeuo pipefail
case "${TIMESCALE_ENABLED:-1}" in 1|true|TRUE|yes|YES|on|ON) ;; *) exit 0 ;; esac
PG_MAJOR="${PG_MAJOR:-17}"
PG_BIN="/usr/lib/postgresql/$PG_MAJOR/bin"
PGDATA="/home/container/timescaledb/data"
TS_ROOT="/home/container/timescaledb"
PG_SOCKET="/home/container/runtime/postgresql"
TS_LOG="${LOG_DIR:-/home/container/logs}/timescaledb"
mkdir -p "$TS_ROOT" "$PG_SOCKET" "$TS_LOG"
chmod 700 "$TS_ROOT"
if [[ -f "$TS_ROOT/connection.env" ]]; then
  source "$TS_ROOT/connection.env"
fi
TIMESCALE_DB_PORT="${TIMESCALE_DB_PORT:-5432}"
TIMESCALE_DB_DATABASE="${TIMESCALE_DB_DATABASE:-${TIMESCALE_DATABASE:-andline_ts}}"
TIMESCALE_DB_USERNAME="${TIMESCALE_DB_USERNAME:-${TIMESCALE_USERNAME:-andline}}"
[[ "$TIMESCALE_DB_PORT" =~ ^[0-9]+$ ]] && (( 10#$TIMESCALE_DB_PORT > 0 && 10#$TIMESCALE_DB_PORT < 65536 )) || { echo "[TIMESCALE] Invalid port"; exit 1; }
for name in "$TIMESCALE_DB_DATABASE" "$TIMESCALE_DB_USERNAME"; do
  [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]{0,62}$ ]] || { echo "[TIMESCALE] Invalid database or role name"; exit 1; }
done
[[ "$TIMESCALE_DB_USERNAME" != postgres ]] || { echo "[TIMESCALE] Choose a dedicated application role"; exit 1; }
if [[ -f "$PGDATA/PG_VERSION" && "$(cat "$PGDATA/PG_VERSION")" != "$PG_MAJOR" ]]; then
  echo "[TIMESCALE] PostgreSQL major version mismatch; migrate the existing cluster before changing PG_MAJOR."
  exit 1
fi

case "${1:-run}" in
  stop)
    if "$PG_BIN/pg_ctl" -D "$PGDATA" status >/dev/null 2>&1; then
      "$PG_BIN/pg_ctl" -D "$PGDATA" -m fast -w -t 120 stop
    fi
    exit 0 ;;
  run)
    [[ -f "$PGDATA/PG_VERSION" ]] || { echo "[TIMESCALE] Cluster has not been initialized"; exit 1; }
    exec "$PG_BIN/postgres" -D "$PGDATA" -p "$TIMESCALE_DB_PORT" -h 127.0.0.1 ;;
  bootstrap) ;;
  *) echo "[TIMESCALE] Usage: bootstrap|run|stop"; exit 1 ;;
esac

if [[ ! -f "$TS_ROOT/connection.env" ]]; then
  umask 077
  TIMESCALE_DB_PASSWORD="${TIMESCALE_DB_PASSWORD:-${TIMESCALE_PASSWORD:-$(head -c 32 /dev/urandom | base64 | tr -d '\n')}}"
  {
    printf 'export TIMESCALE_DB_HOST=127.0.0.1\n'
    printf 'export TIMESCALE_DB_PORT=%q\n' "$TIMESCALE_DB_PORT"
    printf 'export TIMESCALE_DB_DATABASE=%q\n' "$TIMESCALE_DB_DATABASE"
    printf 'export TIMESCALE_DB_USERNAME=%q\n' "$TIMESCALE_DB_USERNAME"
    printf 'export TIMESCALE_DB_PASSWORD=%q\n' "$TIMESCALE_DB_PASSWORD"
  } > "$TS_ROOT/connection.env"
fi

if [[ ! -f "$PGDATA/PG_VERSION" ]]; then
  "$PG_BIN/initdb" -D "$PGDATA" --username=postgres --encoding=UTF8 --locale=C.UTF-8 --auth-local=trust --auth-host=scram-sha-256
  cat >> "$PGDATA/postgresql.conf" <<PGCONF
shared_preload_libraries = 'timescaledb'
unix_socket_directories = '$PG_SOCKET'
password_encryption = 'scram-sha-256'
shared_buffers = '128MB'
work_mem = '4MB'
maintenance_work_mem = '64MB'
max_connections = 50
max_worker_processes = 16
timescaledb.max_background_workers = 4
timescaledb.telemetry_level = 'off'
PGCONF
fi
if ! "$PG_BIN/pg_ctl" -D "$PGDATA" status >/dev/null 2>&1; then
  "$PG_BIN/pg_ctl" -D "$PGDATA" -o "-p $TIMESCALE_DB_PORT -h 127.0.0.1" -l "$TS_LOG/bootstrap.log" -w -t 120 start
fi
"$PG_BIN/psql" -X -q -v ON_ERROR_STOP=1 -h "$PG_SOCKET" -p "$TIMESCALE_DB_PORT" -U postgres -d postgres \
  -v role="$TIMESCALE_DB_USERNAME" -v password="$TIMESCALE_DB_PASSWORD" -v db="$TIMESCALE_DB_DATABASE" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD %L', :'role', :'password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'role') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db', :'role')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db') \gexec
SQL
"$PG_BIN/psql" -X -q -v ON_ERROR_STOP=1 -h "$PG_SOCKET" -p "$TIMESCALE_DB_PORT" -U postgres -d "$TIMESCALE_DB_DATABASE" \
  -c 'CREATE EXTENSION IF NOT EXISTS timescaledb;'
echo "[TIMESCALE] Ready at 127.0.0.1:$TIMESCALE_DB_PORT; connection settings: $TS_ROOT/connection.env"
