#!/usr/bin/env bash
set -Eeuo pipefail

case "${WS_ENABLED:-1}" in
  1|true|TRUE|yes|YES|on|ON) ;;
  *) echo "[ANDBRIDGE] Gateway disabled."; exec sleep infinity ;;
esac

APP_DIR="${APP_DIR:-/home/container/www}"
GATEWAY_DIR="$APP_DIR/server"
SERVER_PORT="${SERVER_PORT:-${HTTP_PORT:-8080}}"

export NODE_ENV="${NODE_ENV:-production}"
export ANDBRIDGE_GATEWAY_HOST="${ANDBRIDGE_GATEWAY_HOST:-127.0.0.1}"
export ANDBRIDGE_GATEWAY_PORT="${ANDBRIDGE_GATEWAY_PORT:-9443}"
export ANDBRIDGE_GATEWAY_PATH="${ANDBRIDGE_GATEWAY_PATH:-/ws/plugin}"
export ANDBRIDGE_ADMIN_PATH="${ANDBRIDGE_ADMIN_PATH:-/ws/admin}"
export ANDBRIDGE_SITE_PATH="${ANDBRIDGE_SITE_PATH:-/ws/site}"
export ANDBRIDGE_PLAYER_PATH="${ANDBRIDGE_PLAYER_PATH:-/ws/player}"
export ANDBRIDGE_LARAVEL_URL="${ANDBRIDGE_LARAVEL_URL:-http://127.0.0.1:$SERVER_PORT}"

if [[ -z "${ANDBRIDGE_GATEWAY_SECRET:-}" ]]; then
  echo "[ANDBRIDGE] ERROR: ANDBRIDGE_GATEWAY_SECRET is required."
  exit 30
fi

if [[ ! -f "$GATEWAY_DIR/src/index.js" ]]; then
  echo "[ANDBRIDGE] ERROR: $GATEWAY_DIR/src/index.js not found."
  exit 31
fi

cd "$GATEWAY_DIR"

echo "[ANDBRIDGE] Laravel: $ANDBRIDGE_LARAVEL_URL"
echo "[ANDBRIDGE] Listening: $ANDBRIDGE_GATEWAY_HOST:$ANDBRIDGE_GATEWAY_PORT$ANDBRIDGE_GATEWAY_PATH"

exec node src/index.js
