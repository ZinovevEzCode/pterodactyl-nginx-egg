#!/usr/bin/env bash
set -Eeuo pipefail

export APP_DIR="${APP_DIR:-/home/container/www}"
export ADMIN_DIR="${ADMIN_DIR:-$APP_DIR/admin}"
export ADMIN_DIST_DIR="${ADMIN_DIST_DIR:-$ADMIN_DIR/dist}"
export WS_DIR="${WS_DIR:-$APP_DIR/nodejs}"
export WS_PORT="${WS_PORT:-3000}"
export WS_PUBLIC_PATH="${WS_PUBLIC_PATH:-/nodejs}"
export SERVER_PORT="${SERVER_PORT:-${HTTP_PORT:-8080}}"
export LOG_DIR="${LOG_DIR:-/home/container/logs}"

WS_PUBLIC_PATH="/${WS_PUBLIC_PATH#/}"
WS_PUBLIC_PATH="${WS_PUBLIC_PATH%/}"
export WS_PUBLIC_PATH

mkdir -p /home/container/runtime/nginx /home/container/tmp/nginx/{client_temp,proxy_temp,fastcgi_temp}

envsubst '$SERVER_PORT $APP_DIR $ADMIN_DIST_DIR $WS_PORT $WS_PUBLIC_PATH' \
  < /opt/andline/nginx/andline.conf.template \
  > /home/container/runtime/nginx/andline.conf

nginx -t -c /opt/andline/nginx/nginx.conf
php-fpm-runtime -tt --fpm-config /opt/andline/php/php-fpm.conf

echo "[ANDLINE] Services successfully launched"
echo "[ANDLINE] HTTP :$SERVER_PORT | WS $WS_PUBLIC_PATH -> 127.0.0.1:$WS_PORT"
exec /usr/bin/supervisord -n -c /opt/andline/supervisor/supervisord.conf
