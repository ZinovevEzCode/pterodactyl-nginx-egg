#!/usr/bin/env bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/www/public/assets/js" "$tmp/logs/build-backups" "$tmp/.npm/_logs"
git -C "$tmp/www" init -q
git -C "$tmp/www" config user.name CI
git -C "$tmp/www" config user.email ci@example.invalid
printf 'live chunk hash abcd1234\n' > "$tmp/www/public/assets/js/app.js"
printf 'tracked chunk\n' > "$tmp/www/public/assets/js/tracked.99887766.js"
git -C "$tmp/www" add public/assets/js/app.js public/assets/js/tracked.99887766.js
git -C "$tmp/www" commit -qm seed
printf 'old but referenced\n' > "$tmp/www/public/assets/js/keep.abcd1234.js"
printf 'old, unreferenced\n' > "$tmp/www/public/assets/js/old.deadbeef.js"
touch -d '60 days ago' "$tmp/www/public/assets/js/"*.js
mkdir -p "$tmp/logs/build-backups/20260101T000000Z-old" "$tmp/logs/build-backups/20260102T000000Z-new"
APP_DIR="$tmp/www" LOG_DIR="$tmp/logs" npm_config_cache="$tmp/.npm" \
  ASSET_RETENTION_DAYS=30 BUILD_BACKUPS_KEEP=1 ASSETS_BUILT=1 CLEAN_NPM_CACHE=0 \
  bash "$repo_root/scripts/maintain-storage.sh" postdeploy
test -f "$tmp/www/public/assets/js/app.js"
test -f "$tmp/www/public/assets/js/tracked.99887766.js"
test -f "$tmp/www/public/assets/js/keep.abcd1234.js"
test ! -e "$tmp/www/public/assets/js/old.deadbeef.js"
test -d "$tmp/logs/build-backups/20260102T000000Z-new"
test ! -e "$tmp/logs/build-backups/20260101T000000Z-old"
echo "ANDLINE storage maintenance smoke passed"
