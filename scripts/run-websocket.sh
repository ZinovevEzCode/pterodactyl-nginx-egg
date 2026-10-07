#!/usr/bin/env bash
set -Eeuo pipefail

case "${WS_ENABLED:-1}" in
  1|true|TRUE|yes|YES|on|ON) ;;
  *) echo "[WS] Disabled."; exec sleep infinity ;;
esac

WS_DIR="${WS_DIR:-/home/container/www/nodejs}"
WS_START_COMMAND="${WS_START_COMMAND:-npm start}"

if [[ ! -f "$WS_DIR/package.json" ]]; then
  echo "[WS] ERROR: package.json not found in $WS_DIR"
  exit 30
fi

cd "$WS_DIR"
echo "[WS] Starting: $WS_START_COMMAND"
exec bash -lc "$WS_START_COMMAND"
