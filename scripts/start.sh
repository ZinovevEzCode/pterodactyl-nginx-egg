#!/usr/bin/env bash
set -Eeuo pipefail

export APP_DIR="${APP_DIR:-/home/container/www}"
export SERVER_PORT="${SERVER_PORT:-${HTTP_PORT:-8080}}"
export LOG_DIR="${LOG_DIR:-/home/container/logs}"

# Prefer ANDLINE_AGENT_*; keep ANDBRIDGE_* aliases for older panel variables still set in-place.
coalesce() {
  local agent="$1" legacy="$2" default="$3"
  printf '%s' "${!agent:-${!legacy:-$default}}"
}

export ANDLINE_AGENT_GATEWAY_PORT="$(coalesce ANDLINE_AGENT_GATEWAY_PORT ANDBRIDGE_GATEWAY_PORT 9443)"
export ANDBRIDGE_GATEWAY_PORT="$ANDLINE_AGENT_GATEWAY_PORT"

normalize_ws_path() {
  local path="${1:-}"
  path="/${path#/}"
  path="${path%/}"
  printf '%s' "$path"
}

export ANDLINE_AGENT_GATEWAY_PATH="$(normalize_ws_path "$(coalesce ANDLINE_AGENT_GATEWAY_PATH ANDBRIDGE_GATEWAY_PATH /ws/plugin)")"
export ANDLINE_AGENT_ADMIN_PATH="$(normalize_ws_path "$(coalesce ANDLINE_AGENT_ADMIN_PATH ANDBRIDGE_ADMIN_PATH /ws/admin)")"
export ANDLINE_AGENT_SITE_PATH="$(normalize_ws_path "$(coalesce ANDLINE_AGENT_SITE_PATH ANDBRIDGE_SITE_PATH /ws/site)")"
export ANDLINE_AGENT_PLAYER_PATH="$(normalize_ws_path "$(coalesce ANDLINE_AGENT_PLAYER_PATH ANDBRIDGE_PLAYER_PATH /ws/player)")"
export ANDBRIDGE_GATEWAY_PATH="$ANDLINE_AGENT_GATEWAY_PATH"
export ANDBRIDGE_ADMIN_PATH="$ANDLINE_AGENT_ADMIN_PATH"
export ANDBRIDGE_SITE_PATH="$ANDLINE_AGENT_SITE_PATH"
export ANDBRIDGE_PLAYER_PATH="$ANDLINE_AGENT_PLAYER_PATH"

# Browser sockets are published by nginx. An empty panel value follows APP_URL.
app_url="${APP_URL:-http://localhost}"
app_url="${app_url%/}"
case "$app_url" in
  https://*) ws_origin="wss://${app_url#https://}" ;;
  http://*) ws_origin="ws://${app_url#http://}" ;;
  wss://*|ws://*) ws_origin="$app_url" ;;
  *) ws_origin="ws://${app_url}" ;;
esac
export ANDLINE_AGENT_ADMIN_WS_URL="$(coalesce ANDLINE_AGENT_ADMIN_WS_URL ANDBRIDGE_ADMIN_WS_URL "${ws_origin}${ANDLINE_AGENT_ADMIN_PATH}")"
export ANDLINE_AGENT_SITE_WS_URL="$(coalesce ANDLINE_AGENT_SITE_WS_URL ANDBRIDGE_SITE_WS_URL "${ws_origin}${ANDLINE_AGENT_SITE_PATH}")"
export ANDLINE_AGENT_PLAYER_WS_URL="$(coalesce ANDLINE_AGENT_PLAYER_WS_URL ANDBRIDGE_PLAYER_WS_URL "${ws_origin}${ANDLINE_AGENT_PLAYER_PATH}")"
export ANDBRIDGE_ADMIN_WS_URL="$ANDLINE_AGENT_ADMIN_WS_URL"
export ANDBRIDGE_SITE_WS_URL="$ANDLINE_AGENT_SITE_WS_URL"
export ANDBRIDGE_PLAYER_WS_URL="$ANDLINE_AGENT_PLAYER_WS_URL"

mkdir -p \
  /home/container/runtime/nginx \
  /home/container/tmp/nginx/client_temp \
  /home/container/tmp/nginx/proxy_temp \
  /home/container/tmp/nginx/fastcgi_temp \
  /home/container/tmp/nginx/scgi_temp \
  "$LOG_DIR/nginx" "$LOG_DIR/php" "$LOG_DIR/node" "$LOG_DIR/laravel" "$LOG_DIR/newt"

# /ws/plugin stays private. Public nginx proxies the three browser paths only.
# Template still uses ANDBRIDGE_* placeholders for envsubst compatibility with older images.
envsubst '$SERVER_PORT $APP_DIR $ANDBRIDGE_GATEWAY_PORT $ANDBRIDGE_ADMIN_PATH $ANDBRIDGE_SITE_PATH $ANDBRIDGE_PLAYER_PATH' \
  < /opt/andline/nginx/andline.conf.template \
  > /home/container/runtime/nginx/andline.conf

/usr/sbin/nginx -t -c /opt/andline/nginx/nginx.conf

echo "[ANDLINE] Services successfully launched"
echo "[ANDLINE] HTTP :$SERVER_PORT"
echo "[ANDLINE] Agent private WSS 127.0.0.1:$ANDLINE_AGENT_GATEWAY_PORT$ANDLINE_AGENT_GATEWAY_PATH"
echo "[ANDLINE] Public WSS $ANDLINE_AGENT_ADMIN_PATH $ANDLINE_AGENT_SITE_PATH $ANDLINE_AGENT_PLAYER_PATH -> 127.0.0.1:$ANDLINE_AGENT_GATEWAY_PORT"

exec /usr/bin/supervisord -n -c /opt/andline/supervisor/supervisord.conf
