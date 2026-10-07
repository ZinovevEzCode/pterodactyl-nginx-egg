FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="ANDLINE Pterodactyl Runtime"

ARG PHP_VERSION=8.5
ARG NODE_MAJOR=24

ENV DEBIAN_FRONTEND=noninteractive \
    PHP_VERSION=${PHP_VERSION} \
    NODE_MAJOR=${NODE_MAJOR} \
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
       php${PHP_VERSION}-zip php${PHP_VERSION}-opcache php${PHP_VERSION}-sockets \
    && ln -sf "/usr/sbin/php-fpm${PHP_VERSION}" /usr/local/bin/php-fpm-runtime \
    && curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php \
    && php /tmp/composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer \
    && rm -f /tmp/composer-setup.php \
    && npm install -g npm@latest \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -d /home/container -s /bin/bash container \
    && mkdir -p /home/container/www /home/container/logs/{nginx,php,node,laravel,build} \
       /home/container/runtime/nginx /home/container/tmp/nginx/{client_temp,proxy_temp,fastcgi_temp} \
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
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh /usr/local/bin/andline-* \
    && ln -sf /opt/andline/php/php.ini "/etc/php/${PHP_VERSION}/cli/conf.d/99-andline.ini" \
    && ln -sf /opt/andline/php/php.ini "/etc/php/${PHP_VERSION}/fpm/conf.d/99-andline.ini"

WORKDIR /home/container
USER container
STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/entrypoint.sh"]
