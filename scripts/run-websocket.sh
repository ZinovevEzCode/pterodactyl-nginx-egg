#!/usr/bin/env bash
set -Eeuo pipefail

case "${ANDLINE_AGENT_ENABLED:-1}" in
  1|true|TRUE|yes|YES|on|ON) ;;
  *) echo "[ANDLINE_AGENT] Gateway disabled."; exec sleep infinity ;;
esac

APP_DIR="${APP_DIR:-/home/container/www}"
GATEWAY_DIR="$APP_DIR/server"
SERVER_PORT="${SERVER_PORT:-${HTTP_PORT:-8080}}"

export NODE_ENV="${NODE_ENV:-production}"
export ANDLINE_AGENT_GATEWAY_HOST="${ANDLINE_AGENT_GATEWAY_HOST:-127.0.0.1}"
export ANDLINE_AGENT_GATEWAY_PORT="${ANDLINE_AGENT_GATEWAY_PORT:-9443}"
export ANDLINE_AGENT_GATEWAY_PATH="${ANDLINE_AGENT_GATEWAY_PATH:-/ws/plugin}"
export ANDLINE_AGENT_PLUGIN_IO_PATH="${ANDLINE_AGENT_PLUGIN_IO_PATH:-/ws/plugin-io}"
export ANDLINE_AGENT_SITE_PATH="${ANDLINE_AGENT_SITE_PATH:-/ws/site}"
export ANDLINE_AGENT_LARAVEL_URL="${ANDLINE_AGENT_LARAVEL_URL:-http://127.0.0.1:$SERVER_PORT}"

if [[ -z "${ANDLINE_AGENT_GATEWAY_SECRET:-}" ]]; then
  echo "[ANDLINE_AGENT] ERROR: ANDLINE_AGENT_GATEWAY_SECRET is required."
  exit 30
fi
secret_lc="$(printf '%s' "$ANDLINE_AGENT_GATEWAY_SECRET" | tr '[:upper:]' '[:lower:]')"
if [[ ${#ANDLINE_AGENT_GATEWAY_SECRET} -lt 24 || "$secret_lc" == change-me* || "$secret_lc" == *changeme* || "$secret_lc" == *secret-xx* ]]; then
  echo "[ANDLINE_AGENT] ERROR: gateway secret is a weak placeholder. Set a unique secret (min 24 chars)."
  exit 30
fi

if [[ ! -f "$GATEWAY_DIR/src/index.js" ]]; then
  echo "[ANDLINE_AGENT] ERROR: $GATEWAY_DIR/src/index.js not found."
  exit 31
fi

cd "$GATEWAY_DIR"

echo "[ANDLINE_AGENT] Laravel: $ANDLINE_AGENT_LARAVEL_URL"
echo "[ANDLINE_AGENT] Browser Socket.IO: $ANDLINE_AGENT_SITE_PATH; private plugin: $ANDLINE_AGENT_PLUGIN_IO_PATH"

exec node src/index.js
