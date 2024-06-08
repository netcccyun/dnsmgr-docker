ARG ALPINE_VERSION=3.19
FROM alpine:${ALPINE_VERSION}
# Setup document root
WORKDIR /app/www

# Install packages and remove default server definition
RUN apk add --no-cache \
  bash \
  curl \
  nginx \
  php82 \
  php82-ctype \
  php82-curl \
  php82-dom \
  php82-fileinfo \
  php82-fpm \
  php82-gd \
  php82-gettext \
  php82-intl \
  php82-iconv \
  php82-mbstring \
  php82-mysqli \
  php82-opcache \
  php82-openssl \
  php82-phar \
  php82-sodium \
  php82-session \
  php82-simplexml \
  php82-tokenizer \
  php82-xml \
  php82-xmlreader \
  php82-xmlwriter \
  php82-zip \
  php82-pdo \
  php82-pdo_mysql \
  php82-pdo_sqlite \
  php82-pecl-swoole \
  supervisor

# Configure nginx - http
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
ENV PHP_INI_DIR /etc/php82
COPY config/fpm-pool.conf ${PHP_INI_DIR}/php-fpm.d/www.conf
COPY config/php.ini ${PHP_INI_DIR}/conf.d/custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Add application
RUN mkdir -p /usr/src && wget https://github.com/netcccyun/dnsmgr/archive/refs/heads/main.zip -O /usr/src/www.zip && unzip /usr/src/www.zip -d /usr/src/ && mv /usr/src/dnsmgr-main /usr/src/www && rm -f /usr/src/www.zip

# Install composer
RUN wget https://mirrors.aliyun.com/composer/composer.phar -O /usr/local/bin/composer && chmod +x /usr/local/bin/composer

RUN composer install -d /usr/src/www --no-dev

RUN adduser -D -s /sbin/nologin -g www www && chown -R www.www /usr/src/www /var/lib/nginx /var/log/nginx

# crontab
RUN echo "*/15 * * * * cd /app/www && /usr/bin/php82 think opiptask" | crontab -u www -

# copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["sh", "/entrypoint.sh"]

# Expose the port nginx is reachable on
EXPOSE 80

# Let supervisord start nginx & php-fpm
CMD crond && /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1/fpm-ping || exit 1
