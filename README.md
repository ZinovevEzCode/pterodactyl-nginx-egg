# ANDLINE — Pterodactyl EGG

Единый runtime: **PHP 8.5 / Laravel**, **Node.js 24 / Socket.IO v4**, **nginx**, MariaDB (внешняя БД), PostgreSQL 17 + TimescaleDB (локальная либо внешняя), **Newt** (опционально).

- EGG для импорта: `egg-andline.json`
- Docker/образ GHCR: `ghcr.io/zinovevezcode/pterodactyl-nginx-egg:andline`
- Источник сайта: приватный `ZinovevAndline/andline`
- Новая система использует только `ANDLINE_AGENT_*`; алиасы `ANDBRIDGE_*` удалены из runtime.

## Порты и Socket.IO

| Назначение | Значение | Где доступно |
|---|---|---|
| HTTP сайта | Pterodactyl SERVER_PORT | Публичный nginx |
| Socket.IO сайта/ЛК/админки | `/ws/site` | Публичный nginx |
| Socket.IO Minecraft-плагинов | `/ws/plugin-io/`, namespace `/plugin` | **Только приватный Gateway** |
| Node Gateway | `127.0.0.1:9443` | Только контейнер |
| Локальный TimescaleDB | `127.0.0.1:5432` | Только контейнер |

У сайта три пространства имён Socket.IO на одном Engine.IO endpoint: `/` (публичный онлайн), `/admin` (админка), `/player` (уведомления). Отдельные `/ws/admin` и `/ws/player` удалены. В nginx закрыт весь префикс `/ws/`, кроме точного публичного `/ws/site`.

Для удалённых Minecraft-серверов нужен **частный TLS endpoint** (VPN / защищённый tunnel / приватный reverse proxy). Не открывайте `/ws/plugin-io` в публичном веб-домене.

## Переменные Pterodactyl

| Переменная | Назначение |
|---|---|
| `GIT_ADDRESS`, `GIT_BRANCH`, `GIT_TOKEN` | Репозиторий, ветка и секретный токен |
| `AUTO_PULL`, `FORCE_BUILD` | Поведение автоматического деплоя |
| `BUILD_FRONTEND`, `BUILD_ADMIN`, `FORCE_NPM_CI` | Какие зависимости/ассеты пересобрать |
| `FRONTEND_BUILD_MODE`, `ADMIN_BUILD_MODE` | `dev` либо `prod` независимо для сайта и админки; смена режима автоматически запускает сборку без нового коммита |
| `ASSET_RETENTION_DAYS`, `BUILD_BACKUPS_KEEP`, `CLEAN_NPM_CACHE` | Безопасная уборка диска: срок хранения устаревших хешированных JS чанков, число резервных копий сборок и опциональная очистка npm cache |
| `APP_ENV`, `APP_DEBUG`, `APP_URL` | Настройки Laravel и публичного HTTPS |
| `DB_*` | Основная MariaDB |
| `TIMESCALE_ENABLED` | 1 — локальный кластер, 0 — внешний |
| `TIMESCALE_HOST`, `TIMESCALE_PORT`, `TIMESCALE_DATABASE`, `TIMESCALE_USERNAME`, `TIMESCALE_PASSWORD`, `TIMESCALE_SSLMODE` | Единые параметры TimescaleDB |
| `ANDLINE_AGENT_ENABLED` | Включает Node Gateway |
| `ANDLINE_AGENT_GATEWAY_PORT` | Внутренний порт Gateway, по умолчанию 9443 |
| `ANDLINE_AGENT_GATEWAY_SECRET` | Общий случайный секрет Laravel/Node (≥32 символа) |
| `ANDLINE_AGENT_PLUGIN_IO_PATH` | Приватный Socket.IO `/ws/plugin-io` |
| `ANDLINE_AGENT_SITE_PATH` | Публичный Socket.IO `/ws/site` |
| `ANDLINE_AGENT_WSS_URL` | Minecraft plugin URL через приватный маршрут |
| `ANDLINE_AGENT_COLLISION_MODE` | Политика конкурирующих сессий |
| `ANDLINE_RELEASES_GITHUB_TOKEN` | **Только для Laravel**: Fine-grained read-only PAT для зеркала приватных Paper, GML и Offline Releases |
| `QUEUE_ENABLED`, `SCHEDULER_ENABLED` | Laravel queue и scheduler |
| `ANDLINE_RELEASES_GITHUB_WEBHOOK_SECRET` | HMAC-секрет для GitHub Release webhook, общий для Agent и Bridge репозиториев; хранится только в Laravel |
| `NEWT_ENABLED`, `PANGOLIN_ENDPOINT`, `NEWT_ID`, `NEWT_SECRET` | Newt |

Адрес `ANDLINE_AGENT_LARAVEL_URL` стартовый скрипт рассчитывает сам как `http://127.0.0.1:$SERVER_PORT`. Адреса браузерного Socket.IO строятся из `APP_URL`. Никакие `ANDBRIDGE_*` или отдельно `ADMIN_WS_URL`, `PLAYER_WS_URL` настраивать не нужно.

## Обновление существующего сервера

**Перед импортом нового EGG запишите текущие значения** Git-токена, секрета Gateway, параметров MariaDB, домена и Newt. Pterodactyl при новом импорте не переносит настройки удалённых полей на новые автоматически.

1. Установите и проверьте совместимую версию `andline` со свежими `ANDLINE_AGENT_*` переменными и единым `/ws/site`.
2. Импортируйте `egg-andline.json` в Pterodactyl, обновите привязку сервера к новой версии EGG и заполните переменные.
3. Убедитесь, что у контейнера есть `ANDLINE_AGENT_GATEWAY_SECRET` длиной не менее 32 символов и правильный HTTPS `APP_URL`.
4. Установите актуальные Paper Agent и оба Bungee Bridge JAR, обязательно настройте `/ws/plugin-io`. Старые RAW WebSocket JAR не подключатся.
5. После запуска проверьте `/healthz`, HTTP сайта, Engine.IO `/ws/site`, handshake плагинов, онлайн и подтверждения покупок.

На новой версии образа Docker автоматически публикуется через GitHub Actions из `main`; PR лишь тестирует, но не публикует продуктивный образ. Запуск в Pterodactyl не выполняется самим merge.

## TimescaleDB

При `TIMESCALE_ENABLED=1` кластер хранится в `/home/container/timescaledb/data`, а реквизиты — в `/home/container/timescaledb/connection.env`. Он доступен только по loopback. **Параметры уже созданного кластера не меняются простым редактированием переменных в панели.** Для изменения пароля/порта требуется явная миграция работающего кластера/конфигурации и резервная копия.

При `TIMESCALE_ENABLED=0` используются указанные `TIMESCALE_HOST`, `TIMESCALE_PORT`, `TIMESCALE_*`.

## Сборка / диагностика

Путь сайта: `/home/container/www`. Старт: `/entrypoint.sh`. При наличии нового Git-коммита выполняются `composer install`, `npm run prod` для сайта/админки, `npm ci --omit=dev` для Node Gateway, миграции и кэширование Laravel. Скрипт не выполняет произвольные команды из EGG и не подменяет Composer зависимости при ошибке.

Сейчас в upstream-сайте может отсутствовать `composer.lock`: это допускается для совместимости, но при таком развёртывании Composer сам разрешает зависимости. **Для воспроизводимого prod рекомендуется закоммитить корректный portable `composer.lock`.**

Логи: `/home/container/logs/{deploy.log,node/,php/,laravel/,nginx/,build/,newt/}`.

Проверка EGG:
```bash
python3 scripts/validate-egg.py egg-andline.json
```

Если импорт возвращает HTTP 500, проверьте **логи самой панели Pterodactyl** и настройку её `APP_SERVICE_AUTHOR`. Это ошибка панели, не Node Gateway.

## Zero-Config плагины и приватные релизы

В текущей архитектуре игровые Java-плагины **не содержат GitHub PAT и не подключаются к GitHub API**. Сайт синхронизирует приватные артефакты:

```bash
cd /home/container/www
php artisan andline:plugin-releases-sync
```

Команда проверяет SHA256SUMS каждого GitHub Release, сохраняет три проверенных JAR в storage/app/andline_agent/plugin, а затем сайт выдаёт их только привязанным серверам с действующим Bearer-токеном. Манифест каждого сервера дополнительно подписывается HMAC. Для регулярных обновлений команда запускается Laravel Scheduler раз в час; включите `SCHEDULER_ENABLED=1`.

Runtime запускает отдельный Supervisor-процесс `laravel-plugin-release-queue`, который
обрабатывает долгие загрузки JAR из очереди `release_database/plugin-releases`.
Очередь работает даже при отключённом планировщике (`SCHEDULER_ENABLED=0`), если
`QUEUE_ENABLED=1`. Смотреть её логи можно в Pterodactyl Files:
`/home/container/logs/laravel/plugin-release-queue.log` и `plugin-release-queue-error.log`.
Для ручной проверки через браузер используйте админку сайта:
**Сервера → Обновления плагинов → Синхронизировать с GitHub** — `php artisan` в консоли не требуется.

В **Pterodactyl EGG сайта** введите `ANDLINE_RELEASES_GITHUB_TOKEN` — токен GitHub только с разрешением Contents: Read-only для репозиториев `andline-agent` и `andlinebridge`. Не передавайте его в переменные игровых серверов.

В **Pterodactyl-окружении каждого игрового Paper/Bungee-сервера** задайте:

- `ANDLINE_SITE_URL=https://<публичный-домен-сайта>` (сайт с HTTPS и API привязки);
- `ANDLINE_STATE_KEY` — уникальный base64-ключ длиной 32 байта до кодирования. Генерация: `openssl rand -base64 32`.

После создания сервера в админке выберите «Создать код привязки», затем в его игровой консоли выполните `/andline pair <код>` для Paper или `/andbridge pair <код>` для GML/Offline. Код действует 5 минут, одноразовый. Плагин создаёт `plugins/<plugin>/state.bin` (AES-256-GCM), сохраняет server ID, API-токен и приватный Socket.IO адрес. Прежний `config.yml` при первом запуске мигрируется и удаляется только после успешного сохранения бинарного файла.

**Сохраняйте ANDLINE_STATE_KEY** в секретах панели / резервной копии. Его утрата делает `state.bin` нечитаемым; автоматически восстановить секреты из JAR нельзя. Не используйте один ключ для всех серверов. Отключите старые резервные копии с незашифрованными `config.yml` или удалите их отдельно после проверки миграции.

Тайный `ANDLINE_AGENT_WSS_URL` на стороне сайта должен указывать на доступный плагинам приватный WSS TLS endpoint (`wss://.../ws/plugin-io`, namespace `/plugin`). Публичный nginx сайта продолжает обслуживать только `/ws/site`.


## Режим сборки и место на диске

- В Pterodactyl обновите EGG из `egg-andline.json` (одной публикации Docker-образа недостаточно для появления новых переменных). Для основного домена рекомендуются `FRONTEND_BUILD_MODE=prod` и `ADMIN_BUILD_MODE=prod`; для тестового стенда можно выставить `dev`.
- `npm run dev` в ANDLINE — **однократная** development-сборка Laravel Mix, не постоянный HMR-процесс. WebSocket и Laravel запускаются независимо от режима сборки.
- Если хотя бы один build mode или BUILD_FRONTEND/BUILD_ADMIN изменился, при следующем запуске будет повторная сборка даже при том же Git SHA. Если сборка выключена флагом BUILD_*, соответствующий режим не применяется до её включения.
- После **успешной** сборки удаляются только JS chunks с хешем в имени, старше `ASSET_RETENTION_DAYS=30`, не отслеживаемые Git и не упомянутые в текущем entrypoint bundle. Не удаляются CSS, изображения, исходники, node_modules, активные ассеты и данные БД. `ASSET_RETENTION_DAYS=0` выключает чистку.
- Папки `/home/container/logs/build-backups` ограничены `BUILD_BACKUPS_KEEP=3` последними резервными копиями; логам `entrypoint.log`, `deploy.log`, `logs/build/*.log` выставлена ротация при достижении 20 MiB (до трёх архивных файлов). `CLEAN_NPM_CACHE=1` очищает npm cache только после успешной сборки, но последующие установки зависимостей будут медленнее.
- Диагностика занятого диска внутри работающего контейнера: `/usr/local/bin/andline-disk-usage`. **Не удаляйте** `/home/container/timescaledb` или `www/storage` — там находятся метрики и пользовательские данные.

