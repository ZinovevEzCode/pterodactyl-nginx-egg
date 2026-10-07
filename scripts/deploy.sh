#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${APP_DIR:-/home/container/www}"
ADMIN_DIR="$APP_DIR/admin"
GATEWAY_DIR="$APP_DIR/server"
LOG_DIR="${LOG_DIR:-/home/container/logs}"
GIT_ADDRESS="${GIT_ADDRESS:-https://github.com/ZinovevEzCode/andline.git}"
GIT_BRANCH="${GIT_BRANCH:-main}"
DEPLOY_MARKER="/home/container/.andline-deploy-sha"

mkdir -p "$APP_DIR" "$LOG_DIR/build"
exec > >(tee -a "$LOG_DIR/deploy.log") 2>&1

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

git_auth() {
  if [[ -n "${GIT_TOKEN:-}" ]]; then
    local encoded
    encoded="$(printf 'x-access-token:%s' "$GIT_TOKEN" | base64 | tr -d '\n')"
    git -c "http.extraHeader=Authorization: Basic $encoded" "$@"
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

npm_build() {
  local dir="$1"
  local name="$2"
  local command="$3"
  local lock_file="$dir/package-lock.json"
  local lock_marker="/home/container/.andline-npm-${name}.locksha"
  local lock_hash=""
  local prev_hash=""

  [[ -f "$dir/package.json" ]] || {
    echo "[BUILD][$name] package.json not found in $dir"
    return 1
  }

  export npm_config_cache="${npm_config_cache:-/home/container/.npm}"
  mkdir -p "$npm_config_cache"

  if [[ -f "$lock_file" ]]; then
    lock_hash="$(sha256sum "$lock_file" | awk '{print $1}')"
  fi
  prev_hash="$(cat "$lock_marker" 2>/dev/null || true)"

  if [[ ! -d "$dir/node_modules" ]] || [[ -z "$lock_hash" ]] || [[ "$lock_hash" != "$prev_hash" ]] || is_true "${FORCE_NPM_CI:-0}"; then
    echo "[BUILD][$name] npm ci"
    run_logged "$LOG_DIR/build/$name.log" bash -lc "cd '$dir' && npm ci"
    if [[ -n "$lock_hash" ]]; then
      printf '%s\n' "$lock_hash" > "$lock_marker"
    fi
  else
    echo "[BUILD][$name] npm ci skipped (lock unchanged, node_modules present)"
  fi

  echo "[BUILD][$name] $command"
  run_logged "$LOG_DIR/build/$name.log" bash -lc "cd '$dir' && $command"
}

composer_install() {
  local composer_log="$LOG_DIR/build/composer.log"

  if [[ -n "${GIT_TOKEN:-}" ]]; then
    export COMPOSER_AUTH="{\"github-oauth\":{\"github.com\":\"${GIT_TOKEN}\"}}"
  fi

  echo "[BUILD][composer] composer install"
  if run_logged "$composer_log" bash -lc "cd '$APP_DIR' && composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader"; then
    return 0
  fi

  if ! is_true "${COMPOSER_PATH_FALLBACK:-1}"; then
    echo "[BUILD][composer] install failed and COMPOSER_PATH_FALLBACK=0"
    return 1
  fi

  if ! grep -q '"type": "path"' "$APP_DIR/composer.lock" 2>/dev/null; then
    echo "[BUILD][composer] install failed for a reason unrelated to path repositories"
    return 1
  fi

  echo "[BUILD][composer] WARNING: composer.lock contains local Windows path packages."
  echo "[BUILD][composer] Falling back to public Composer repositories for this deployment."

  local prod_json="$APP_DIR/composer.pterodactyl.json"
  local prod_lock="$APP_DIR/composer.pterodactyl.lock"

  php -r '
    $file = $argv[1];
    $out = $argv[2];
    $json = json_decode(file_get_contents($file), true, 512, JSON_THROW_ON_ERROR);
    $json["require"]["backpack/crud"] = "dev-v8 as 8.0.0";
    $json["repositories"] = [[
        "type" => "vcs",
        "url" => "https://github.com/Laravel-Backpack/CRUD.git"
    ]];
    file_put_contents($out, json_encode($json, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL);
  ' "$APP_DIR/composer.json" "$prod_json"

  set +e
  (
    cd "$APP_DIR"
    COMPOSER="composer.pterodactyl.json" composer update       --no-dev       --prefer-dist       --no-interaction       --optimize-autoloader       --with-all-dependencies
  ) 2>&1 | tee -a "$composer_log"
  local code=${PIPESTATUS[0]}
  set -e

  rm -f "$prod_json" "$prod_lock"

  return "$code"
}

echo "[DEPLOY] Repository: $GIT_ADDRESS"
echo "[DEPLOY] Branch: $GIT_BRANCH"

if [[ ! -d "$APP_DIR/.git" ]]; then
  if [[ -n "$(find "$APP_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    echo "[DEPLOY] ERROR: $APP_DIR is not empty and is not a Git repository."
    exit 20
  fi

  echo "[DEPLOY] Cloning application."
  git_auth clone --branch "$GIT_BRANCH" --single-branch "$GIT_ADDRESS" "$APP_DIR"
elif is_true "${AUTO_PULL:-1}"; then
  cd "$APP_DIR"
  echo "[DEPLOY] Syncing origin/$GIT_BRANCH."
  git_auth fetch --prune origin "$GIT_BRANCH"
  # Discard previous build dirt on tracked assets so the tree matches origin.
  git checkout -B "$GIT_BRANCH" "origin/$GIT_BRANCH"
  git reset --hard "origin/$GIT_BRANCH"
fi

cd "$APP_DIR"

if [[ ! -f .env && -f .env.example ]]; then
  echo "[LARAVEL] Creating persistent .env from .env.example."
  cp .env.example .env
fi

HEAD_SHA="$(git rev-parse HEAD)"
LAST_SHA="$(cat "$DEPLOY_MARKER" 2>/dev/null || true)"
NEEDS_BUILD=0

if is_true "${FORCE_BUILD:-0}" || [[ "$HEAD_SHA" != "$LAST_SHA" ]] || [[ ! -f vendor/autoload.php ]]; then
  NEEDS_BUILD=1
fi

if [[ "$NEEDS_BUILD" -eq 1 ]]; then
  echo "[DEPLOY] Building revision $HEAD_SHA."

  export COMPOSER_HOME="${COMPOSER_HOME:-/home/container/.composer}"
  export npm_config_cache="${npm_config_cache:-/home/container/.npm}"
  mkdir -p "$COMPOSER_HOME" "$npm_config_cache"

  composer_install

  if is_true "${BUILD_FRONTEND:-1}"; then
    npm_build "$APP_DIR" "frontend" "${ROOT_BUILD_COMMAND:-npm run prod}"
  else
    echo "[BUILD][frontend] skipped (BUILD_FRONTEND=0)"
  fi

  if is_true "${BUILD_ADMIN:-1}"; then
    npm_build "$ADMIN_DIR" "admin" "${ADMIN_BUILD_COMMAND:-npm run prod}"
  else
    echo "[BUILD][admin] skipped (BUILD_ADMIN=0)"
  fi

  echo "[BUILD][gateway] Installing production dependencies."
  if [[ -f "$GATEWAY_DIR/package-lock.json" ]]; then
    local_gw_marker="/home/container/.andline-npm-gateway.locksha"
    local_gw_hash="$(sha256sum "$GATEWAY_DIR/package-lock.json" | awk '{print $1}')"
    local_gw_prev="$(cat "$local_gw_marker" 2>/dev/null || true)"
    if [[ ! -d "$GATEWAY_DIR/node_modules" ]] || [[ "$local_gw_hash" != "$local_gw_prev" ]] || is_true "${FORCE_NPM_CI:-0}"; then
      run_logged "$LOG_DIR/build/gateway.log" bash -lc "cd '$GATEWAY_DIR' && npm ci --omit=dev"
      printf '%s\n' "$local_gw_hash" > "$local_gw_marker"
    else
      echo "[BUILD][gateway] npm ci skipped (lock unchanged)"
    fi
  else
    run_logged "$LOG_DIR/build/gateway.log" bash -lc "cd '$GATEWAY_DIR' && npm install --omit=dev"
  fi
else
  echo "[DEPLOY] Revision unchanged; Composer and Webpack builds skipped."
fi

mkdir -p storage/framework/{cache,sessions,views} storage/logs bootstrap/cache

if [[ -f artisan ]]; then
  if ! grep -Eq '^APP_KEY=base64:.+' .env 2>/dev/null && [[ -z "${APP_KEY:-}" ]]; then
    echo "[LARAVEL] Generating APP_KEY."
    php artisan key:generate --force
  fi

  if ! grep -Eq '^JWT_SECRET=.+' .env 2>/dev/null && [[ -z "${JWT_SECRET:-}" ]]; then
    echo "[LARAVEL] Generating JWT_SECRET."
    php artisan jwt:secret --force
  fi

  echo "[LARAVEL] Clearing stale cached configuration."
  php artisan optimize:clear

  if is_true "${RUN_MIGRATIONS:-1}"; then
    echo "[LARAVEL] Running migrations."
    php artisan migrate --force
  fi

  if is_true "${RUN_SEEDERS:-0}"; then
    echo "[LARAVEL] Running database seeders."
    php artisan db:seed --force
  fi

  if [[ -d public && ! -e public/storage && -d storage/app/public ]]; then
    php artisan storage:link || true
  fi

  if is_true "${LARAVEL_OPTIMIZE:-1}"; then
    echo "[LARAVEL] Rebuilding production caches."
    php artisan optimize
  fi
fi

if [[ "$NEEDS_BUILD" -eq 1 ]]; then
  printf '%s\n' "$HEAD_SHA" > "$DEPLOY_MARKER"
fi

echo "[DEPLOY] ANDLINE deployment completed."
