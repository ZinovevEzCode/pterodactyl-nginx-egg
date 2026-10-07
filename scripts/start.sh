#!/usr/bin/env bash
set -Eeuo pipefail

export APP_DIR="${APP_DIR:-/home/container/www}"
export SERVER_PORT="${SERVER_PORT:-${HTTP_PORT:-8080}}"
export LOG_DIR="${LOG_DIR:-/home/container/logs}"

export ANDBRIDGE_GATEWAY_PORT="${ANDBRIDGE_GATEWAY_PORT:-9443}"
export ANDBRIDGE_GATEWAY_PATH="${ANDBRIDGE_GATEWAY_PATH:-/bridge}"

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

envsubst '$SERVER_PORT $APP_DIR $ANDBRIDGE_GATEWAY_PORT $ANDBRIDGE_GATEWAY_PATH'   < /opt/andline/nginx/andline.conf.template   > /home/container/runtime/nginx/andline.conf

/usr/sbin/nginx -t -c /opt/andline/nginx/nginx.conf
php-fpm-runtime -tt --fpm-config /opt/andline/php/php-fpm.conf

echo "[ANDLINE] Services successfully launched"
echo "[ANDLINE] HTTP :$SERVER_PORT"
echo "[ANDLINE] AndBridge $ANDBRIDGE_GATEWAY_PATH -> 127.0.0.1:$ANDBRIDGE_GATEWAY_PORT"

exec /usr/bin/supervisord -n -c /opt/andline/supervisor/supervisord.conf
