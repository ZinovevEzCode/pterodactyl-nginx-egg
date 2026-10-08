#!/usr/bin/env bash
set -Eeuo pipefail

export APP_DIR="${APP_DIR:-/home/container/www}"
export SERVER_PORT="${SERVER_PORT:-${HTTP_PORT:-8080}}"
export LOG_DIR="${LOG_DIR:-/home/container/logs}"

export ANDBRIDGE_GATEWAY_PORT="${ANDBRIDGE_GATEWAY_PORT:-9443}"
export ANDBRIDGE_GATEWAY_PATH="${ANDBRIDGE_GATEWAY_PATH:-/bridge-plugin}"

ANDBRIDGE_GATEWAY_PATH="/${ANDBRIDGE_GATEWAY_PATH#/}"
ANDBRIDGE_GATEWAY_PATH="${ANDBRIDGE_GATEWAY_PATH%/}"
export ANDBRIDGE_GATEWAY_PATH

mkdir -p \
  /home/container/runtime/nginx \
  /home/container/tmp/nginx/client_temp \
  /home/container/tmp/nginx/proxy_temp \
  /home/container/tmp/nginx/fastcgi_temp \
  /home/container/tmp/nginx/uwsgi_temp \
  /home/container/tmp/nginx/scgi_temp \
  "$LOG_DIR/nginx" "$LOG_DIR/php" "$LOG_DIR/node" "$LOG_DIR/laravel" "$LOG_DIR/newt"

# Plugin path stays private. Public nginx proxies only /bridge-admin and /bridge-live.
envsubst '$SERVER_PORT $APP_DIR $ANDBRIDGE_GATEWAY_PORT'   < /opt/andline/nginx/andline.conf.template   > /home/container/runtime/nginx/andline.conf

/usr/sbin/nginx -t -c /opt/andline/nginx/nginx.conf
php-fpm-runtime -tt --fpm-config /opt/andline/php/php-fpm.conf

echo "[ANDLINE] Services successfully launched"
echo "[ANDLINE] HTTP :$SERVER_PORT"
echo "[ANDLINE] AndBridge private WSS 127.0.0.1:$ANDBRIDGE_GATEWAY_PORT$ANDBRIDGE_GATEWAY_PATH"
echo "[ANDLINE] Public WSS /bridge-admin and /bridge-live -> 127.0.0.1:$ANDBRIDGE_GATEWAY_PORT"

exec /usr/bin/supervisord -n -c /opt/andline/supervisor/supervisord.conf
