#!/usr/bin/env bash
set -Eeuo pipefail

case "${QUEUE_ENABLED:-1}" in
  1|true|TRUE|yes|YES|on|ON) ;;
  *) echo "[QUEUE] Disabled."; exec sleep infinity ;;
esac

APP_DIR="${APP_DIR:-/home/container/www}"
cd "$APP_DIR"

[[ -f artisan ]] || { echo "[QUEUE] artisan not found"; exit 31; }

exec php artisan queue:work   --sleep="${QUEUE_SLEEP:-1}"   --tries="${QUEUE_TRIES:-3}"   --timeout="${QUEUE_TIMEOUT:-120}"   --max-time="${QUEUE_MAX_TIME:-3600}"
