# ANDLINE Pterodactyl Runtime

Production runtime, tailored specifically for the private repository `ZinovevEzCode/andline`.

## Runtime

- Nginx
- PHP 8.5 + PHP-FPM
- Composer 2
- Node.js 24 + npm
- Supervisor
- Newt 1.18.1 for Pangolin (optional)

PHP drivers include MariaDB/MySQL, PostgreSQL/TimescaleDB and SQLite support.

## ANDLINE repository layout

The runtime expects the real application layout:

```text
/home/container/www
├── artisan
├── composer.json
├── package.json
├── webpack.mix.js
├── admin/
│   ├── package.json
│   └── webpack.mix.js
├── server/
│   ├── package.json
│   └── src/index.js
├── public/
└── resources/
```

### Public frontend

Root `package.json` uses Laravel Mix / Webpack and is built with:

```bash
npm ci
npm run prod
```

Output goes to `public/assets/js`.

### Admin

`admin/webpack.mix.js` writes directly to:

```text
public/assets/admin
```

The admin URL itself is a Laravel route/Blade shell:

```text
/admin
/admin/*
```

Nginx therefore does **not** serve an independent `/admin/dist` SPA.

### AndBridge gateway

The real gateway is:

```text
/home/container/www/server/src/index.js
```

Runtime defaults:

```env
NODE_ENV=production
ANDBRIDGE_GATEWAY_HOST=127.0.0.1
ANDBRIDGE_GATEWAY_PORT=9443
ANDBRIDGE_GATEWAY_PATH=/bridge
```

Supervisor starts it directly with:

```bash
node src/index.js
```

Nginx proxies:

```text
/bridge -> 127.0.0.1:9443
```

with 24-hour WebSocket read/send timeouts.

The internal Laravel URL is generated automatically as:

```text
http://127.0.0.1:<PTERODACTYL_SERVER_PORT>
```

so the gateway talks back to Laravel through the local Nginx instance.

## Git deployment

Default repository:

```text
https://github.com/ZinovevEzCode/andline.git
```

The repository is private, so configure `GIT_TOKEN` in the Pterodactyl egg. The token is sent as an HTTP Basic header and is never written into `.git/config`.

On startup:

1. clone/sync `main`;
2. create persistent `.env` from `.env.example` if missing;
3. detect whether the Git revision changed;
4. on a new revision:
   - install Composer dependencies;
   - build root Vue/Laravel Mix;
   - build admin Materio/Laravel Mix;
   - install `server/` production dependencies;
5. generate `APP_KEY` and `JWT_SECRET` if missing;
6. clear stale Laravel caches;
7. run migrations if enabled;
8. optionally run seeders;
9. rebuild production caches;
10. start services through Supervisor.

Changing Pterodactyl environment variables does not require a source-code change: Laravel caches are rebuilt on each container start.

## Composer path-repository compatibility

The current ANDLINE `composer.lock` contains packages installed from local Windows paths such as:

```text
C:/Users/User/Desktop/dreamcms/vendor/...
```

Those paths do not exist in Linux/Pterodactyl.

Deployment first tries the normal:

```bash
composer install --no-dev --prefer-dist --optimize-autoloader
```

If it fails and the lock contains path distributions, `COMPOSER_PATH_FALLBACK=1` creates a temporary production Composer definition without the local `repositories` section and resolves the declared package constraints from public Composer repositories.

This is a compatibility bridge. Long term, the ANDLINE repository should regenerate `composer.lock` from portable repositories so deployment is completely reproducible.

## Supervisor processes

```text
php-fpm
nginx
andbridge gateway
laravel queue worker
laravel scheduler
newt (optional)
```

Newt starts last so the local web/gateway stack is already available before Pangolin exposes it.

## Logs

```text
/home/container/logs/
├── entrypoint.log
├── deploy.log
├── supervisord.log
├── build/
│   ├── composer.log
│   ├── frontend.log
│   ├── admin.log
│   └── gateway.log
├── nginx/
├── php/
├── laravel/
├── node/
│   ├── andbridge-gateway.log
│   └── andbridge-gateway-error.log
└── newt/
```

## Important Pterodactyl variables

Application:

```env
APP_ENV=production
APP_DEBUG=false
APP_URL=https://your-domain.example
```

Primary database:

```env
DB_CONNECTION=mariadb
DB_HOST=...
DB_PORT=3306
DB_DATABASE=andline
DB_USERNAME=andline
DB_PASSWORD=...
```

TimescaleDB:

```env
TIMESCALE_HOST=...
TIMESCALE_PORT=5432
TIMESCALE_DATABASE=andline_ts
TIMESCALE_USERNAME=andline
TIMESCALE_PASSWORD=...
TIMESCALE_SSLMODE=prefer
```

AndBridge:

```env
ANDBRIDGE_GATEWAY_SECRET=<long-random-secret>
ANDBRIDGE_GATEWAY_PORT=9443
ANDBRIDGE_GATEWAY_PATH=/bridge
ANDBRIDGE_WSS_URL=wss://your-domain.example/bridge
ANDBRIDGE_COLLISION_MODE=LAST_WINS
```

Pangolin/Newt:

```env
NEWT_ENABLED=1
PANGOLIN_ENDPOINT=https://pangolin.example
NEWT_ID=...
NEWT_SECRET=...
```

## Nginx + Pangolin

Nginx preserves an incoming `X-Forwarded-Proto` from Pangolin/Newt. This matters because the AndBridge gateway rejects insecure WebSocket connections in production.

Laravel also receives the forwarded HTTPS scheme through FastCGI.

## Pterodactyl

Import:

```text
egg-andline.json
```

Target image after CI publishes it:

```text
ghcr.io/zinovevezcode/pterodactyl-nginx-egg:andline
```
