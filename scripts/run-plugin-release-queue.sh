#!/usr/bin/env bash
set -Eeuo pipefail

case "${QUEUE_ENABLED:-1}" in
  1|true|TRUE|yes|YES|on|ON) ;;
  *) echo "[PLUGIN_RELEASES] Queue disabled in Pterodactyl settings."; exec sleep infinity ;;
esac

APP_DIR="${APP_DIR:-/home/container/www}"
cd "$APP_DIR"
[[ -f artisan ]] || { echo "[PLUGIN_RELEASES] artisan not found"; exit 31; }

echo "[PLUGIN_RELEASES] Starting dedicated release_database worker for plugin-releases"
echo "[PLUGIN_RELEASES] JAR mirroring and Node notification retry automatically without console commands"

# The release job can download a 50MB private JAR. The runtime queue worker
# uses 120-second timeouts, so these jobs require their own 300-second worker.
# Laravel's release_database retry_after=360 prevents overlapping delivery.
exec php artisan queue:work release_database \
  --queue=plugin-releases \
  --sleep=2 \
  --tries=6 \
  --timeout=300 \
  --max-time=3600
