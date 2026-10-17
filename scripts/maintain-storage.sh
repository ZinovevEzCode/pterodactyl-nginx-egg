#!/usr/bin/env bash
# Limited maintenance of ANDLINE's generated data; never touches TimescaleDB, storage/app or user uploads.
set -Eeuo pipefail
APP_DIR="${APP_DIR:-/home/container/www}"
LOG_DIR="${LOG_DIR:-/home/container/logs}"
CACHE_DIR="${npm_config_cache:-/home/container/.npm}"
ASSET_RETENTION_DAYS="${ASSET_RETENTION_DAYS:-30}"
BUILD_BACKUPS_KEEP="${BUILD_BACKUPS_KEEP:-3}"
for pair in "ASSET_RETENTION_DAYS:$ASSET_RETENTION_DAYS:365" "BUILD_BACKUPS_KEEP:$BUILD_BACKUPS_KEEP:30"; do
  IFS=: read -r label number maximum <<< "$pair"
  if ! [[ "$number" =~ ^[0-9]+$ ]] || (( 10#$number > maximum )); then
    echo "[STORAGE] Invalid $label: $number" >&2
    exit 64
  fi
done

rotate_log() {
  local file="$1" n
  [[ -f "$file" && ! -L "$file" ]] || return 0
  local bytes
  bytes="$(stat -c '%s' -- "$file")"
  (( bytes >= 20 * 1024 * 1024 )) || return 0
  rm -f -- "$file.3"
  for n in 2 1; do
    [[ -f "$file.$n" ]] && mv -f -- "$file.$n" "$file.$((n+1))"
  done
  mv -f -- "$file" "$file.1"
  echo "[STORAGE] Rotated $file ($bytes bytes)"
}

prune_backups() {
  local root="$LOG_DIR/build-backups" name i
  [[ -d "$root" ]] || return 0
  local -a backups=()
  mapfile -t backups < <(find "$root" -mindepth 1 -maxdepth 1 -type d -name '20??????T??????Z-*' -printf '%f\n' | sort -r)
  for (( i=BUILD_BACKUPS_KEEP; i<${#backups[@]}; i++ )); do
    name="${backups[$i]}"
    echo "[STORAGE] Removing excess build backup: $name"
    rm -rf -- "$root/$name"
  done
}

prune_chunks() {
  local dir="$1" entry="$2" file rel name hash
  (( ASSET_RETENTION_DAYS > 0 )) || return 0
  [[ -d "$dir" && -f "$entry" && ! -L "$dir" && -d "$APP_DIR/.git" ]] || return 0
  while IFS= read -r -d '' file; do
    name="${file##*/}"
    # Only generated hashed chunks, never app.js, source files or non-JS assets.
    [[ "$name" =~ \.([0-9a-fA-F]{8,})\.js$ ]] || continue
    hash="${BASH_REMATCH[1]}"
    rel="${file#"$APP_DIR/"}"
    [[ "$rel" != "$file" ]] || continue
    # Git-tracked bundles must never be touched, regardless of age.
    if git -C "$APP_DIR" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then continue; fi
    # Webpack runtimes include hashes of live async chunks. Keep these.
    if grep -Fq -- "$hash" "$entry"; then continue; fi
    echo "[STORAGE] Removing aged unreferenced JS chunk: $rel"
    rm -f -- "$file"
  done < <(find "$dir" -type f -name '*.js' -mmin "+$((ASSET_RETENTION_DAYS * 1440))" -print0)
}

case "${1:-}" in
  rotate-entrypoint)
    mkdir -p "$LOG_DIR"
    rotate_log "$LOG_DIR/entrypoint.log"
    ;;
  rotate-deploy)
    mkdir -p "$LOG_DIR/build"
    rotate_log "$LOG_DIR/deploy.log"
    while IFS= read -r -d '' file; do rotate_log "$file"; done < <(find "$LOG_DIR/build" -maxdepth 1 -type f -name '*.log' -print0)
    ;;
  postdeploy)
    prune_backups
    if [[ "${ASSETS_BUILT:-0}" == 1 ]]; then
      prune_chunks "$APP_DIR/public/assets/js" "$APP_DIR/public/assets/js/app.js"
      prune_chunks "$APP_DIR/public/assets/admin/js" "$APP_DIR/public/assets/admin/js/main.js"
      if [[ "${CLEAN_NPM_CACHE:-0}" == 1 && -d "$CACHE_DIR" ]]; then
        echo "[STORAGE] Clearing npm download cache"
        npm cache clean --force || echo "[STORAGE] npm cache cleanup skipped" >&2
      fi
    fi
    if [[ -d "$CACHE_DIR/_logs" ]]; then
      find "$CACHE_DIR/_logs" -maxdepth 1 -type f -name '*.log' -mtime +14 -delete
    fi
    ;;
  *) echo "Usage: $0 rotate-entrypoint|rotate-deploy|postdeploy" >&2; exit 64 ;;
esac
