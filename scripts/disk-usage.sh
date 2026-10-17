#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${APP_DIR:-/home/container/www}"
echo "[ANDLINE] Disk space:"
df -h /home/container
echo
echo "[ANDLINE] Largest site directories:"
for path in "$ROOT/public/assets" "$ROOT/node_modules" "$ROOT/admin/node_modules" "$ROOT/server/node_modules" \
  "/home/container/.npm" "/home/container/logs/build-backups" "/home/container/logs" \
  "$ROOT/storage/logs" "/home/container/timescaledb/data" "$ROOT/vendor"; do
  [[ -e "$path" ]] && du -sh -- "$path"
done
