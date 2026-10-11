#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p /home/container/runtime/nginx /home/container/logs/nginx
mkdir -p /home/container/tmp/nginx/{client_temp,proxy_temp,fastcgi_temp,uwsgi_temp,scgi_temp}
export APP_DIR=/home/container/www
export SERVER_PORT=8080
export ANDLINE_AGENT_GATEWAY_PORT=9443
export ANDLINE_AGENT_SITE_PATH=/ws/site

envsubst '$SERVER_PORT $APP_DIR $ANDLINE_AGENT_GATEWAY_PORT $ANDLINE_AGENT_SITE_PATH' \
  < /opt/andline/nginx/andline.conf.template \
  > /home/container/runtime/nginx/andline.conf
/usr/sbin/nginx -t -c /opt/andline/nginx/nginx.conf
grep -Fq 'location = /ws/site' /home/container/runtime/nginx/andline.conf
grep -Fq 'location ^~ /ws/' /home/container/runtime/nginx/andline.conf
if grep -Eq 'location.*(/ws/admin|/ws/player)' /home/container/runtime/nginx/andline.conf; then
  echo '[NGINX] Legacy browser WS paths must not be exposed'
  exit 33
fi
echo '[NGINX] Socket.IO endpoint and plugin deny-list OK'
