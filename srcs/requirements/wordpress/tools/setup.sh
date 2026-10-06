#!/bin/sh

if [ ! -f "wp-config.php" ]; then
    wp core download --allow-root


    wp config create \
        --dbname=$MYSQL_DATABASE \
        --dbuser=$MYSQL_USER \
        --dbpass=$MYSQL_PASSWORD \
        --dbhost=mariadb \
        --allow-root


    wp core install \
        --url=$DOMAIN_NAME \
        --title=$SITE_TITLE \
        --admin_user=$ADMIN_USER \
        --admin_password=$ADMIN_PASSWORD \
        --admin_email=$ADMIN_EMAIL \
        --allow-root


    wp user create \
        $USER1_NAME \
        $USER1_EMAIL \
        --user_pass=$USER1_PASS \
        --role=author \
        --allow-root
fi


exec /usr/sbin/php-fpm8.2 -F