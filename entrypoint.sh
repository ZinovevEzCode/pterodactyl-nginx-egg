#!/usr/bin/env bash
set -Eeuo pipefail

export APP_DIR="${APP_DIR:-/home/container/www}"
export LOG_DIR="${LOG_DIR:-/home/container/logs}"

mkdir -p "$APP_DIR" "$LOG_DIR"/{nginx,php,node,laravel,build} /home/container/runtime/nginx /home/container/tmp/nginx/{client_temp,proxy_temp,fastcgi_temp}

exec > >(tee -a "$LOG_DIR/entrypoint.log") 2>&1

echo "[ANDLINE] Container startup: $(date -Iseconds)"
/usr/local/bin/andline-deploy
exec /usr/local/bin/andline-start
