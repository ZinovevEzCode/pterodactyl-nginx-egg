#!/usr/bin/env bash
set -Eeuo pipefail

case "${NEWT_ENABLED:-0}" in
  1|true|TRUE|yes|YES|on|ON) ;;
  *) echo "[NEWT] Disabled."; exec sleep infinity ;;
esac

missing=0
for name in PANGOLIN_ENDPOINT NEWT_ID NEWT_SECRET; do
  if [[ -z "${!name:-}" ]]; then
    echo "[NEWT] ERROR: $name is required when NEWT_ENABLED=1"
    missing=1
  fi
done

[[ "$missing" -eq 0 ]] || exit 33

export HEALTH_FILE="${HEALTH_FILE:-/home/container/runtime/newt/healthy}"
mkdir -p "$(dirname "$HEALTH_FILE")"
rm -f "$HEALTH_FILE"

echo "[NEWT] Starting userspace tunnel to $PANGOLIN_ENDPOINT"
exec /usr/local/bin/newt
