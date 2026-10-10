#!/usr/bin/env bash
set -Eeuo pipefail

case "${WS_ENABLED:-1}" in
  1|true|TRUE|yes|YES|on|ON) ;;
  *) echo "[ANDLINE_AGENT] Gateway disabled."; exec sleep infinity ;;
esac

APP_DIR="${APP_DIR:-/home/container/www}"
GATEWAY_DIR="$APP_DIR/server"
SERVER_PORT="${SERVER_PORT:-${HTTP_PORT:-8080}}"

# Prefer ANDLINE_AGENT_*; accept legacy ANDBRIDGE_* from older eggs.
export_agent() {
  local suffix="$1"
  local default="${2:-}"
  local agent_key="ANDLINE_AGENT_${suffix}"
  local legacy_key="ANDBRIDGE_${suffix}"
  local value="${!agent_key:-${!legacy_key:-$default}}"
  export "$agent_key=$value"
  # Keep legacy export so older nginx templates / helpers still work.
  export "$legacy_key=$value"
}

export NODE_ENV="${NODE_ENV:-production}"
export_agent GATEWAY_HOST "127.0.0.1"
export_agent GATEWAY_PORT "9443"
export_agent GATEWAY_PATH "/ws/plugin"
export_agent ADMIN_PATH "/ws/admin"
export_agent SITE_PATH "/ws/site"
export_agent PLAYER_PATH "/ws/player"
export_agent LARAVEL_URL "http://127.0.0.1:$SERVER_PORT"
export_agent GATEWAY_SECRET ""

if [[ -z "${ANDLINE_AGENT_GATEWAY_SECRET:-}" ]]; then
  echo "[ANDLINE_AGENT] ERROR: ANDLINE_AGENT_GATEWAY_SECRET (or ANDBRIDGE_GATEWAY_SECRET) is required."
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
echo "[ANDLINE_AGENT] Listening: $ANDLINE_AGENT_GATEWAY_HOST:$ANDLINE_AGENT_GATEWAY_PORT$ANDLINE_AGENT_GATEWAY_PATH"

exec node src/index.js
