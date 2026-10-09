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
CREATE MATERIALIZED VIEW runtime_smoke_1h
  WITH (timescaledb.continuous) AS
  SELECT time_bucket(INTERVAL '1 hour', time) AS bucket,
         AVG(value) AS value_avg
  FROM runtime_smoke
  GROUP BY bucket
  WITH NO DATA;
SELECT add_continuous_aggregate_policy('runtime_smoke_1h',
  start_offset => INTERVAL '2 days',
  end_offset => INTERVAL '1 hour',
  schedule_interval => INTERVAL '15 minutes',
  if_not_exists => TRUE);
SELECT add_retention_policy('runtime_smoke', INTERVAL '30 days', if_not_exists => TRUE);
-- This INSERT verifies that continuous aggregate invalidation is available
-- (the Apache-only package rejects these Community Edition features).
INSERT INTO runtime_smoke VALUES (now(), 2);
SQL
license="$(psql "${psql_args[@]}" -Atc 'SHOW timescaledb.license')"
if [[ "$license" != timescale ]]; then
  echo "[TIMESCALE] ERROR: Community Edition required, got license=$license" >&2
  exit 1
fi
test "$(stat -c %a /home/container/timescaledb/connection.env)" = 600
/usr/local/bin/andline-timescaledb stop
/usr/local/bin/andline-timescaledb bootstrap
test "$(psql "${psql_args[@]}" -Atc "SELECT count(*) FROM runtime_smoke")" = 2
echo "[TIMESCALE] Community continuous aggregate, retention, INSERT and restart persistence smoke passed"
