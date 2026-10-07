#!/usr/bin/env bash
set -Eeuo pipefail

case "${SCHEDULER_ENABLED:-1}" in
  1|true|TRUE|yes|YES|on|ON) ;;
  *) echo "[SCHEDULER] Disabled."; exec sleep infinity ;;
esac

APP_DIR="${APP_DIR:-/home/container/www}"
cd "$APP_DIR"

[[ -f artisan ]] || { echo "[SCHEDULER] artisan not found"; exit 32; }

exec php artisan schedule:work
