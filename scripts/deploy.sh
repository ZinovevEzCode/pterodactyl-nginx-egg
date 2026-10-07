#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${APP_DIR:-/home/container/www}"
ADMIN_DIR="${ADMIN_DIR:-$APP_DIR/admin}"
WS_DIR="${WS_DIR:-$APP_DIR/nodejs}"
LOG_DIR="${LOG_DIR:-/home/container/logs}"
GIT_BRANCH="${GIT_BRANCH:-main}"
DEPLOY_MARKER="/home/container/.andline-deploy-sha"

mkdir -p "$APP_DIR" "$LOG_DIR/build"
exec > >(tee -a "$LOG_DIR/deploy.log") 2>&1

is_true() {
  case "${1:-}" in 1|true|TRUE|yes|YES|on|ON) return 0 ;; *) return 1 ;; esac
}

git_auth() {
  if [[ -n "${GIT_TOKEN:-}" ]]; then
    git -c "http.extraHeader=Authorization: Bearer ${GIT_TOKEN}" "$@"
  else
    git "$@"
  fi
}

run_logged() {
  local logfile="$1"
  shift
  set +e
  "$@" 2>&1 | tee -a "$logfile"
  local code=${PIPESTATUS[0]}
  set -e
  return "$code"
}

npm_install_and_build() {
  local dir="$1"
  local command="${2:-}"
  local name="$3"

  [[ -f "$dir/package.json" ]] || return 0

  echo "[BUILD][$name] dependencies"
  if [[ -f "$dir/package-lock.json" ]]; then
    run_logged "$LOG_DIR/build/$name.log" bash -lc "cd '$dir' && npm ci"
  else
    run_logged "$LOG_DIR/build/$name.log" bash -lc "cd '$dir' && npm install"
  fi

  if [[ -n "$command" ]]; then
    run_logged "$LOG_DIR/build/$name.log" bash -lc "cd '$dir' && $command"
  elif (cd "$dir" && node -e "const p=require('./package.json');process.exit(p.scripts&&p.scripts.build?0:1)"); then
    run_logged "$LOG_DIR/build/$name.log" bash -lc "cd '$dir' && npm run build"
  elif (cd "$dir" && node -e "const p=require('./package.json');process.exit(p.scripts&&p.scripts.production?0:1)"); then
    run_logged "$LOG_DIR/build/$name.log" bash -lc "cd '$dir' && npm run production"
  else
    echo "[BUILD][$name] No build script detected."
  fi
}

if [[ -n "${GIT_ADDRESS:-}" ]]; then
  if [[ ! -d "$APP_DIR/.git" ]]; then
    if [[ -n "$(find "$APP_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
      echo "[DEPLOY] ERROR: $APP_DIR is not empty and is not a Git repository."
      exit 20
    fi
    echo "[DEPLOY] Cloning $GIT_ADDRESS branch $GIT_BRANCH"
    git_auth clone --branch "$GIT_BRANCH" --single-branch "$GIT_ADDRESS" "$APP_DIR"
  elif is_true "${AUTO_PULL:-1}"; then
    cd "$APP_DIR"
    echo "[DEPLOY] Updating origin/$GIT_BRANCH"
    git_auth fetch --prune origin "$GIT_BRANCH"
    git checkout -B "$GIT_BRANCH" "origin/$GIT_BRANCH"
  fi
fi

HEAD_SHA=""
if [[ -d "$APP_DIR/.git" ]]; then
  HEAD_SHA="$(git -C "$APP_DIR" rev-parse HEAD)"
fi

NEEDS_BUILD=0
if is_true "${FORCE_BUILD:-0}"; then
  NEEDS_BUILD=1
elif [[ -n "$HEAD_SHA" ]]; then
  LAST_SHA="$(cat "$DEPLOY_MARKER" 2>/dev/null || true)"
  [[ "$HEAD_SHA" != "$LAST_SHA" ]] && NEEDS_BUILD=1
elif [[ -f "$APP_DIR/composer.json" && ! -f "$APP_DIR/vendor/autoload.php" ]]; then
  NEEDS_BUILD=1
fi

if [[ "$NEEDS_BUILD" -eq 0 ]]; then
  echo "[DEPLOY] No new revision; build skipped."
  exit 0
fi

if [[ -f "$APP_DIR/composer.json" ]]; then
  run_logged "$LOG_DIR/build/composer.log" bash -lc "cd '$APP_DIR' && composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader"
fi

npm_install_and_build "$APP_DIR" "${ROOT_BUILD_COMMAND:-}" "frontend"
npm_install_and_build "$ADMIN_DIR" "${ADMIN_BUILD_COMMAND:-}" "admin"

if [[ -f "$WS_DIR/package.json" ]]; then
  if [[ -f "$WS_DIR/package-lock.json" ]]; then
    run_logged "$LOG_DIR/build/websocket.log" bash -lc "cd '$WS_DIR' && npm ci"
  else
    run_logged "$LOG_DIR/build/websocket.log" bash -lc "cd '$WS_DIR' && npm install"
  fi
fi

if [[ -f "$APP_DIR/artisan" ]]; then
  cd "$APP_DIR"
  mkdir -p storage/framework/{cache,sessions,views} storage/logs bootstrap/cache

  if is_true "${RUN_MIGRATIONS:-1}"; then
    php artisan migrate --force
  fi

  if is_true "${LARAVEL_OPTIMIZE:-1}"; then
    php artisan optimize:clear
    php artisan optimize
  fi

  if [[ -d public && ! -e public/storage && -d storage/app/public ]]; then
    php artisan storage:link || true
  fi
fi

[[ -n "$HEAD_SHA" ]] && printf '%s\n' "$HEAD_SHA" > "$DEPLOY_MARKER"
echo "[DEPLOY] Completed successfully."
