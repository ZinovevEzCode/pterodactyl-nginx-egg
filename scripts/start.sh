#!/usr/bin/env bash
set -Eeuo pipefail

export APP_DIR="${APP_DIR:-/home/container/www}"
export SERVER_PORT="${SERVER_PORT:-${HTTP_PORT:-8080}}"
export LOG_DIR="${LOG_DIR:-/home/container/logs}"

export ANDBRIDGE_GATEWAY_PORT="${ANDBRIDGE_GATEWAY_PORT:-9443}"

normalize_ws_path() {
  local path="${1:-}"
  path="/${path#/}"
  path="${path%/}"
  printf '%s' "$path"
}

export ANDBRIDGE_GATEWAY_PATH="$(normalize_ws_path "${ANDBRIDGE_GATEWAY_PATH:-/ws/plugin}")"
export ANDBRIDGE_ADMIN_PATH="$(normalize_ws_path "${ANDBRIDGE_ADMIN_PATH:-/ws/admin}")"
export ANDBRIDGE_SITE_PATH="$(normalize_ws_path "${ANDBRIDGE_SITE_PATH:-/ws/site}")"
export ANDBRIDGE_PLAYER_PATH="$(normalize_ws_path "${ANDBRIDGE_PLAYER_PATH:-/ws/player}")"

# Browser sockets are published by nginx. An empty panel value follows APP_URL.
app_url="${APP_URL:-http://localhost}"
app_url="${app_url%/}"
case "$app_url" in
  https://*) ws_origin="wss://${app_url#https://}" ;;
  http://*) ws_origin="ws://${app_url#http://}" ;;
  wss://*|ws://*) ws_origin="$app_url" ;;
  *) ws_origin="ws://${app_url}" ;;
esac
export ANDBRIDGE_ADMIN_WS_URL="${ANDBRIDGE_ADMIN_WS_URL:-${ws_origin}${ANDBRIDGE_ADMIN_PATH}}"
export ANDBRIDGE_SITE_WS_URL="${ANDBRIDGE_SITE_WS_URL:-${ws_origin}${ANDBRIDGE_SITE_PATH}}"
export ANDBRIDGE_PLAYER_WS_URL="${ANDBRIDGE_PLAYER_WS_URL:-${ws_origin}${ANDBRIDGE_PLAYER_PATH}}"

mkdir -p \
  /home/container/runtime/nginx \
  /home/container/tmp/nginx/client_temp \
  /home/container/tmp/nginx/proxy_temp \
  /home/container/tmp/nginx/fastcgi_temp \
  /home/container/tmp/nginx/uwsgi_temp \
  /home/container/tmp/nginx/scgi_temp \
  "$LOG_DIR/nginx" "$LOG_DIR/php" "$LOG_DIR/node" "$LOG_DIR/laravel" "$LOG_DIR/newt"

# /ws/plugin stays private. Public nginx proxies the three browser paths only.
envsubst '$SERVER_PORT $APP_DIR $ANDBRIDGE_GATEWAY_PORT $ANDBRIDGE_ADMIN_PATH $ANDBRIDGE_SITE_PATH $ANDBRIDGE_PLAYER_PATH' \
  < /opt/andline/nginx/andline.conf.template \
  > /home/container/runtime/nginx/andline.conf

/usr/sbin/nginx -t -c /opt/andline/nginx/nginx.conf

echo "[ANDLINE] Services successfully launched"
echo "[ANDLINE] HTTP :$SERVER_PORT"
echo "[ANDLINE] AndBridge private WSS 127.0.0.1:$ANDBRIDGE_GATEWAY_PORT$ANDBRIDGE_GATEWAY_PATH"
echo "[ANDLINE] Public WSS $ANDBRIDGE_ADMIN_PATH $ANDBRIDGE_SITE_PATH $ANDBRIDGE_PLAYER_PATH -> 127.0.0.1:$ANDBRIDGE_GATEWAY_PORT"

exec /usr/bin/supervisord -n -c /opt/andline/supervisor/supervisord.conf
