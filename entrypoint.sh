#!/usr/bin/env bash
set -Eeuo pipefail

export APP_DIR="${APP_DIR:-/home/container/www}"
export LOG_DIR="${LOG_DIR:-/home/container/logs}"

mkdir -p "$APP_DIR" "$LOG_DIR"/{nginx,php,node,laravel,build,newt} /home/container/runtime/nginx /home/container/runtime/newt /home/container/tmp/nginx/{client_temp,proxy_temp,fastcgi_temp}

exec > >(tee -a "$LOG_DIR/entrypoint.log") 2>&1

echo "[ANDLINE] Container startup: $(date -Iseconds)"
trap '/usr/local/bin/andline-timescaledb stop || true' EXIT
/usr/local/bin/andline-timescaledb bootstrap
case "${TIMESCALE_ENABLED:-1}" in
  1|true|TRUE|yes|YES|on|ON)
    source /home/container/timescaledb/connection.env
    export TIMESCALE_HOST="$TIMESCALE_DB_HOST" TIMESCALE_PORT="$TIMESCALE_DB_PORT"
    export TIMESCALE_DATABASE="$TIMESCALE_DB_DATABASE" TIMESCALE_USERNAME="$TIMESCALE_DB_USERNAME"
    export TIMESCALE_PASSWORD="$TIMESCALE_DB_PASSWORD" TIMESCALE_SSLMODE=disable
    ;;
esac
/usr/local/bin/andline-deploy
/usr/local/bin/andline-timescaledb stop
trap - EXIT
exec /usr/local/bin/andline-start
