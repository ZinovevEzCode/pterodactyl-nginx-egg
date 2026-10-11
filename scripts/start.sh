#!/usr/bin/env bash
set -Eeuo pipefail

export APP_DIR="${APP_DIR:-/home/container/www}"
export SERVER_PORT="${SERVER_PORT:-${HTTP_PORT:-8080}}"
export LOG_DIR="${LOG_DIR:-/home/container/logs}"

# Единые имена переменных EGG. Три браузерных namespace используют /ws/site.
export ANDLINE_AGENT_GATEWAY_PORT="${ANDLINE_AGENT_GATEWAY_PORT:-9443}"
export ANDLINE_AGENT_PLUGIN_IO_PATH="${ANDLINE_AGENT_PLUGIN_IO_PATH:-/ws/plugin-io}"
export ANDLINE_AGENT_SITE_PATH="${ANDLINE_AGENT_SITE_PATH:-/ws/site}"

mkdir -p \
  /home/container/runtime/nginx \
  /home/container/tmp/nginx/client_temp \
  /home/container/tmp/nginx/proxy_temp \
  /home/container/tmp/nginx/fastcgi_temp \
  /home/container/tmp/nginx/scgi_temp \
  "$LOG_DIR/nginx" "$LOG_DIR/php" "$LOG_DIR/node" "$LOG_DIR/laravel" "$LOG_DIR/newt"

# The private plugin path remain inaccessible via the public nginx vhost.
envsubst '$SERVER_PORT $APP_DIR $ANDLINE_AGENT_GATEWAY_PORT $ANDLINE_AGENT_SITE_PATH' \
  < /opt/andline/nginx/andline.conf.template \
  > /home/container/runtime/nginx/andline.conf

/usr/sbin/nginx -t -c /opt/andline/nginx/nginx.conf

echo "[ANDLINE] Services successfully launched"
echo "[ANDLINE] HTTP :$SERVER_PORT"
echo "[ANDLINE] Public Socket.IO $ANDLINE_AGENT_SITE_PATH -> 127.0.0.1:$ANDLINE_AGENT_GATEWAY_PORT"
echo "[ANDLINE] Private Socket.IO $ANDLINE_AGENT_PLUGIN_IO_PATH (not public)"

exec /usr/bin/supervisord -n -c /opt/andline/supervisor/supervisord.conf
