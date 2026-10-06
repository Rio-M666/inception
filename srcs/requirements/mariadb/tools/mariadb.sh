#!/bin/bash

# MySQL サービスを開始
service mariadb start

# MySQL が完全に起動し、通信可能になるまでポーリング（疎通確認）を行う
while ! mysqladmin ping --silent; do
    sleep 1
done

# データベースの作成（存在しない場合）
mariadb -e "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;"

# ユーザーの作成と権限付与
# '%' は「どのホストからでも接続可能」を意味する
mariadb -e "CREATE USER IF NOT EXISTS \`${MYSQL_USER}\`@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';"
mariadb -e "GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO \`${MYSQL_USER}\`@'%';"

# root パスワードの設定と権限のフラッシュ
mariadb -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';"
mariadb -e "FLUSH PRIVILEGES;"

# 設定反映のため一度 MySQL を停止
mysqladmin -u root -p$MYSQL_ROOT_PASSWORD shutdown

# MySQL をフォアグラウンドで再起動（これがコンテナのメインプロセスになる）
exec mysqld_safe