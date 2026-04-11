# Multi-stage build
FROM alpine:3.20 AS builder

ARG BAIKAL_VERSION=0.11.1
# Optional: set this to a real value to verify the download
ARG BAIKAL_SHA256=""

RUN set -eux; \
  apk add --no-cache ca-certificates curl unzip; \
  curl -fsSL -o /tmp/baikal.zip "https://github.com/sabre-io/Baikal/releases/download/${BAIKAL_VERSION}/baikal-${BAIKAL_VERSION}.zip"; \
  if [ -n "${BAIKAL_SHA256}" ]; then echo "${BAIKAL_SHA256}  /tmp/baikal.zip" | sha256sum -c -; fi; \
  unzip -q /tmp/baikal.zip -d /tmp; \
  mv /tmp/baikal /baikal

# Final image
FROM nginx:1.26-bookworm

# Install PHP 8.5 (Sury) + runtime deps
RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends ca-certificates curl gnupg; \
  curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg; \
  . /etc/os-release; \
  echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/php.list; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    php8.5-curl \
    php8.5-fpm \
    php8.5-mbstring \
    php8.5-mysql \
    php8.5-pgsql \
    php8.5-sqlite3 \
    php8.5-xml \
    sqlite3 \
    msmtp msmtp-mta; \
  rm -rf /var/lib/apt/lists/*; \
  sed -i 's/www-data/nginx/' /etc/php/8.5/fpm/pool.d/www.conf; \
  sed -i 's/^listen = .*/listen = \/var\/run\/php-fpm.sock/' /etc/php/8.5/fpm/pool.d/www.conf

# Config + app
COPY files/docker-entrypoint.d/*.sh files/docker-entrypoint.d/*.php files/docker-entrypoint.d/nginx/ /docker-entrypoint.d/
COPY --from=builder --chown=nginx:nginx /baikal /var/www/baikal
COPY files/nginx.conf /etc/nginx/conf.d/default.conf

VOLUME ["/var/www/baikal/config", "/var/www/baikal/Specific"]
