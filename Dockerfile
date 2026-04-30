FROM alpine:3.20

RUN apk --update --no-cache add bash curl wget unzip nginx ca-certificates imagemagick librsvg

RUN apk add --no-cache \
    php83 \
    php83-fpm \
    php83-opcache \
    php83-gd \
    php83-curl \
    php83-xml \
    php83-xmlwriter \
    php83-xmlreader \
    php83-simplexml \
    php83-zip \
    php83-mbstring \
    php83-session \
    php83-pdo \
    php83-pdo_sqlite \
    php83-pdo_mysql \
    php83-pdo_pgsql \
    php83-intl \
    php83-bcmath \
    php83-ctype \
    php83-dom \
    php83-fileinfo \
    php83-iconv \
    php83-openssl \
    php83-exif \
    php83-bz2 \
    php83-posix \
    php83-pcntl \
    php83-apcu \
    php83-gmp \
    php83-sodium \
    php83-sysvsem \
    php83-pecl-imagick

RUN ln -sf /usr/bin/php83 /usr/bin/php

USER container
ENV USER=container
ENV HOME=/home/container

WORKDIR /home/container
COPY ./entrypoint.sh /entrypoint.sh

CMD ["/bin/bash", "/entrypoint.sh"]
