FROM debian:trixie
RUN apt-get update&&apt-get install -y php-fpm
RUN mkdir -p /run/php
RUN apt-get install -y php7.4-fpm
RUN apt-get install -y php7.4-mysql
RUN apt-get install -y mariadb-client

COPY www.conf /etc/php/8.4/fpm/pool.d/.

CMD ["php-fpm8.4","-F"]