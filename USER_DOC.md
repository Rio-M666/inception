# 利用・管理手順

## 提供するサービス

- NGINX：HTTPS の入口。ホストへ公開するポートは 443 のみです。
- WordPress / PHP-FPM：サイトと管理画面を提供します。
- MariaDB：WordPress のユーザー・投稿・コメント・設定を保存します。

## 起動と停止

初回は [DEV_DOC.md](DEV_DOC.md) に従い Docker の保存先と `srcs/.env` を設定してください。リポジトリのルートで操作します。

```bash
make
make down
```

停止しても、WordPress のファイルと DB は Named Volume に残ります。`make fclean` と `make re` は保存データも削除するため、通常の停止には使いません。

## サイトと管理画面

- サイト：`https://mrio.42.fr/`
- ログイン：`https://mrio.42.fr/wp-login.php`
- 管理画面：`https://mrio.42.fr/wp-admin/`

ブラウザを動かすマシンで、ドメインが VM の IP を指す必要があります。自己署名証明書の警告が表示されます。HTTP のポート 80 は公開しません。

## 認証情報の管理

初期設定値はローカルの `srcs/.env` にあります。管理者用は `ADMIN_USER` / `ADMIN_PASSWORD`、一般ユーザー用は `USER1_NAME` / `USER1_PASS` です。パスワードや `.env` を Git・公開ログ・画面共有に載せないでください。

既存サイトでは DB 内のユーザー情報が使用されます。`.env` を変更するだけでは、既存ユーザーのパスワードは更新されません。通常の変更は WordPress 管理画面のユーザープロフィールから行ってください。

## 稼働と保存先の確認

```bash
docker compose --project-name inception --env-file srcs/.env -f srcs/docker-compose.yml ps -a
docker compose --project-name inception --env-file srcs/.env -f srcs/docker-compose.yml logs --tail=50
docker volume inspect inception_wordpress_data inception_mariadb_data
```

3 サービスが起動し、サイトと管理画面を開けることを確認します。ボリュームの `Mountpoint` は `/home/mrio/data/docker/volumes/` 配下です。Docker が管理するため、このディレクトリのファイルを直接削除・編集しないでください。

永続化を確認する場合は、ページを編集して `make down`、`make` の順に実行し、編集が残っていることを確認します。評価時には VM の再起動後にも確認します。
