#!/usr/bin/env bash
set -Eeuo pipefail
trap '/usr/local/bin/andline-timescaledb stop || true' EXIT
/usr/local/bin/andline-timescaledb bootstrap
source /home/container/timescaledb/connection.env
export PGPASSWORD="$TIMESCALE_DB_PASSWORD"
psql_args=(-X -h 127.0.0.1 -p "$TIMESCALE_DB_PORT" -U "$TIMESCALE_DB_USERNAME" -d "$TIMESCALE_DB_DATABASE" -v ON_ERROR_STOP=1)
psql "${psql_args[@]}" <<'SQL'
CREATE TABLE runtime_smoke (time timestamptz NOT NULL, value integer);
SELECT create_hypertable('runtime_smoke', 'time');
INSERT INTO runtime_smoke VALUES (now(), 1);
SQL
test "$(stat -c %a /home/container/timescaledb/connection.env)" = 600
/usr/local/bin/andline-timescaledb stop
/usr/local/bin/andline-timescaledb bootstrap
test "$(psql "${psql_args[@]}" -Atc "SELECT count(*) FROM runtime_smoke")" = 1
echo "[TIMESCALE] Hypertable and restart persistence smoke test passed"
