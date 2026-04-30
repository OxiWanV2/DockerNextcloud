FROM alpine:3.19

RUN apk --update --no-cache add bash curl wget unzip nginx ca-certificates

RUN apk add --no-cache \
    php82 \
    php82-fpm \
    php82-opcache \
    php82-gd \
    php82-curl \
    php82-xml \
    php82-xmlwriter \
    php82-xmlreader \
    php82-simplexml \
    php82-zip \
    php82-mbstring \
    php82-session \
    php82-pdo \
    php82-pdo_sqlite \
    php82-pdo_mysql \
    php82-pdo_pgsql \
    php82-intl \
    php82-bcmath \
    php82-ctype \
    php82-dom \
    php82-fileinfo \
    php82-iconv \
    php82-openssl \
    php82-exif \
    php82-bz2 \
    php82-posix

RUN ln -sf /usr/bin/php82 /usr/bin/php

USER container
ENV USER=container
ENV HOME=/home/container

WORKDIR /home/container
COPY ./entrypoint.sh /entrypoint.sh

CMD ["/bin/bash", "/entrypoint.sh"]
