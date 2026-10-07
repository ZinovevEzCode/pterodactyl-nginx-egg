# ANDLINE Pterodactyl Runtime

Минимальный production-runtime для ANDLINE.

## Состав

- Nginx
- PHP 8.5 + PHP-FPM
- Composer 2
- Node.js 24 + npm
- Laravel
- основной Vue/Webpack build
- отдельный Vue/Webpack build в `/admin`
- Node.js WebSocket
- Newt 1.18.1 для Pangolin (опционально)
- Laravel queue worker
- Laravel scheduler
- Supervisor
- MySQL/MariaDB + PostgreSQL/TimescaleDB PHP drivers
- Git auto-deploy
- раздельные логи

Удалены WordPress, Certbot, Cloudflared, ionCube и старый модульный orchestrator.

## Структура приложения

По умолчанию:

- Laravel/frontend: `/home/container/www`
- Admin: `/home/container/www/admin`
- Admin dist: `/home/container/www/admin/dist`
- WebSocket: `/home/container/www/nodejs`
- Logs: `/home/container/logs`

Все пути для admin/WS можно переопределить переменными egg.

## Git deploy

При старте контейнера:

1. Если приложения ещё нет — клонируется `GIT_ADDRESS`.
2. При `AUTO_PULL=1` ветка синхронизируется с `origin/GIT_BRANCH`.
3. Текущий commit сравнивается с последним успешно собранным.
4. Composer и npm запускаются только при новой ревизии (или `FORCE_BUILD=1`).
5. Root frontend и `/admin` собираются отдельно.
6. Устанавливаются зависимости WebSocket.
7. Выполняются Laravel migrations/optimize.
8. Supervisor запускает runtime-процессы.

Для private repository используется `GIT_TOKEN`; он не записывается в remote URL.

## Frontend

Root и admin не работают через webpack-dev-server в production.

Автоматически ищется:

- `npm run build`
- затем `npm run production`

Можно переопределить:

- `ROOT_BUILD_COMMAND`
- `ADMIN_BUILD_COMMAND`

## WebSocket

По умолчанию:

- каталог: `/home/container/www/nodejs`
- команда: `npm start`
- localhost port: `3000`
- внешний path Nginx: `/nodejs`

## Логи

- `logs/entrypoint.log`
- `logs/deploy.log`
- `logs/build/frontend.log`
- `logs/build/admin.log`
- `logs/build/websocket.log`
- `logs/nginx/*`
- `logs/php/*`
- `logs/node/*`
- `logs/newt/newt.log`
- `logs/newt/newt-error.log`
- `logs/laravel/*`
- `logs/supervisord.log`

## Pterodactyl

Импортируй `egg-andline.json`.

Docker image после успешной GitHub Actions сборки:

`ghcr.io/zinovevezcode/pterodactyl-nginx-egg:andline`

## Newt / Pangolin

Newt встроен в Docker image и работает в userspace-режиме под Supervisor.

Переменные Pterodactyl:

- `NEWT_ENABLED=1`
- `PANGOLIN_ENDPOINT=https://pangolin.example.com`
- `NEWT_ID=<site id>`
- `NEWT_SECRET=<site secret>`

`NEWT_ID` и `NEWT_SECRET` в egg скрыты от обычного просмотра. Не добавляй эти значения в Git или `.env.example`.

При `NEWT_ENABLED=0` Newt не подключается и не влияет на остальные сервисы контейнера.

Health-файл Newt по умолчанию: `/home/container/runtime/newt/healthy`.

> Upstream Newt постепенно заменяется Pangolin CLI (`pangolin site up`). Runtime пока фиксирует Newt 1.18.1, чтобы деплой был воспроизводимым.
