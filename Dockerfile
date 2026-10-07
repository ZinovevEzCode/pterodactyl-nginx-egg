FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="ANDLINE Pterodactyl Runtime"

ARG PHP_VERSION=8.5
ARG NODE_MAJOR=24
ARG NEWT_VERSION=1.18.1

ENV DEBIAN_FRONTEND=noninteractive \
    PHP_VERSION=${PHP_VERSION} \
    NODE_MAJOR=${NODE_MAJOR} \
    NEWT_VERSION=${NEWT_VERSION} \
    HOME=/home/container \
    APP_DIR=/home/container/www

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl git gnupg2 unzip nginx supervisor gettext-base procps tini \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/keyrings/php-sury.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/php-sury.gpg] https://packages.sury.org/php/ bookworm main" > /etc/apt/sources.list.d/php.list \
    && curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       nodejs \
       php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-common \
       php${PHP_VERSION}-mysql php${PHP_VERSION}-pgsql \
       php${PHP_VERSION}-curl php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml \
       php${PHP_VERSION}-bcmath php${PHP_VERSION}-intl php${PHP_VERSION}-gd \
       php${PHP_VERSION}-zip php${PHP_VERSION}-sockets \
    && ln -sf "/usr/sbin/php-fpm${PHP_VERSION}" /usr/local/bin/php-fpm-runtime \
    && curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php \
    && php /tmp/composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer \
    && rm -f /tmp/composer-setup.php \
    && npm install -g npm@latest \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) asset="newt_linux_amd64"; checksum="26deaf4478375b1f7380c4b8be18c8266ab4c476c6d5715972d629a512915832" ;; \
      arm64) asset="newt_linux_arm64"; checksum="4def626ea3a7c25591e00855c32f5456295a871590571958d28ce470831d9952" ;; \
      *) echo "Unsupported architecture for Newt: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/fosrl/newt/releases/download/${NEWT_VERSION}/$asset" -o /usr/local/bin/newt; \
    echo "$checksum  /usr/local/bin/newt" | sha256sum -c -; \
    chmod +x /usr/local/bin/newt

RUN useradd -m -d /home/container -s /bin/bash container \
    && mkdir -p /home/container/www /home/container/logs/nginx /home/container/logs/php /home/container/logs/node \
       /home/container/logs/laravel /home/container/logs/build /home/container/logs/newt \
       /home/container/runtime/nginx /home/container/runtime/newt \
       /home/container/tmp/nginx/client_temp /home/container/tmp/nginx/proxy_temp \
       /home/container/tmp/nginx/fastcgi_temp \
    && chown -R container:container /home/container

COPY nginx/nginx.conf /opt/andline/nginx/nginx.conf
COPY nginx/conf.d/andline.conf.template /opt/andline/nginx/andline.conf.template
COPY php/php-fpm.conf /opt/andline/php/php-fpm.conf
COPY php/pool.d/www.conf /opt/andline/php/pool.d/www.conf
COPY php/php.ini /opt/andline/php/php.ini
COPY supervisor/supervisord.conf /opt/andline/supervisor/supervisord.conf
COPY scripts/deploy.sh /usr/local/bin/andline-deploy
COPY scripts/start.sh /usr/local/bin/andline-start
COPY scripts/run-websocket.sh /usr/local/bin/andline-websocket
COPY scripts/run-queue.sh /usr/local/bin/andline-queue
COPY scripts/run-scheduler.sh /usr/local/bin/andline-scheduler
COPY scripts/run-newt.sh /usr/local/bin/andline-newt
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh /usr/local/bin/andline-* \
    && ln -sf /opt/andline/php/php.ini "/etc/php/${PHP_VERSION}/cli/conf.d/99-andline.ini" \
    && ln -sf /opt/andline/php/php.ini "/etc/php/${PHP_VERSION}/fpm/conf.d/99-andline.ini"

WORKDIR /home/container
USER container
STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/entrypoint.sh"]
