FROM debian:trixie


RUN apt-get update&&apt-get install -y \
    php7.4-fpm \
    php7.4-mysql \
    mariadb-client \




COPY www.conf /etc/php/8.4/fpm/pool.d/.

RUN mkdir -p /run/php


CMD ["php-fpm8.4","-F"]