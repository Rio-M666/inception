# 開発環境とストレージ

## 前提条件と初期設定

- この課題専用の Linux VM、Docker Engine、Docker Compose、GNU Make を使用します。
- Docker の管理権限と、デーモン設定を変更するためのホスト管理者権限が必要です。
- `srcs/.env` は Git に登録せずローカルで作成し、`chmod 600 srcs/.env` で保護します。
- 変数は `LOGIN`、`DOMAIN_NAME`、`MYSQL_DATABASE`、`MYSQL_USER`、`MYSQL_PASSWORD`、`MYSQL_ROOT_PASSWORD`、`SITE_TITLE`、`ADMIN_USER`、`ADMIN_PASSWORD`、`ADMIN_EMAIL`、`USER1_NAME`、`USER1_EMAIL`、`USER1_PASS` を用意します。
- `LOGIN=mrio`、`DOMAIN_NAME=https://mrio.42.fr` を現在の設定と対応させます。別のログイン名を使う場合は NGINX のドメイン・証明書設定も合わせて変更します。
- ブラウザ側の hosts で `mrio.42.fr` を VM の IP に解決させます。VM 内のブラウザからは `127.0.0.1` を利用できます。

## Docker の保存先を設定する

Compose の `wordpress_data` と `mariadb_data` は、追加の driver options を使わない通常の Named Volume です。プロジェクトの永続ストレージには Bind Mount を使いません。

Docker デーモンの `data-root` を `/home/<LOGIN>/data/docker` に設定することで、これらのボリュームを `/home/<LOGIN>/data/` 配下に保存します。設定ファイルの原本は `srcs/docker/daemon.json` です。JSON 内のログイン名は自動展開されないため、別のユーザーで使う場合は明示的に変更してください。

**この設定は VM 全体の Docker に適用されます。既存環境の保存先変更はデータの自動移行を行いません。既存データがある場合は、先に下記の移行手順を読んでください。**

新規の課題専用 VM で、既存の Docker データや設定がない場合：

```bash
sudo install -d /etc/docker
sudo install -m 644 srcs/docker/daemon.json /etc/docker/daemon.json
sudo dockerd --validate --config-file=/etc/docker/daemon.json
sudo systemctl restart docker
docker info --format '{{.DockerRootDir}}'
```

期待する表示は `/home/mrio/data/docker` です。既存の `daemon.json` がある場合はバックアップし、他の設定を残して `data-root` を追加・更新します。

Docker が containerd image store を使う場合、イメージやスナップショットは別途 `/var/lib/containerd` に保存されることがあります。今回のボリュームの保存先は `data-root` で決まります。

## ビルドと起動

リポジトリのルートで実行します。

```bash
make
docker compose --project-name inception --env-file srcs/.env -f srcs/docker-compose.yml ps -a
```

`make` は Docker の保存先が `/home/<LOGIN>/data/docker` と一致することを確認してから、Compose でビルド・起動します。

繰り返し操作する場合は Bash に次の関数を定義します。

```bash
dc() {
  docker compose --project-name inception --env-file srcs/.env -f srcs/docker-compose.yml "$@"
}
dc logs --tail=100
dc exec wordpress wp core is-installed --allow-root
```

## 停止・削除とデータの寿命

| コマンド | 動作 | サイトと DB のデータ |
| --- | --- | --- |
| `make down` | コンテナとプロジェクトのネットワークを削除 | Named Volume に残る |
| `make clean` | 上記に加え、プロジェクトのイメージを削除 | Named Volume に残る |
| `make fclean` | 上記に加え、プロジェクトの Named Volume を削除 | **削除される** |
| `make re` | `fclean` の後に再ビルド・起動 | **初期化される** |

`fclean` は Compose が管理するリソースだけを削除し、`/home/<LOGIN>/data` や Docker の管理ディレクトリを `rm -rf` しません。永続化の確認には `make down` と `make` を使います。

## 保存先の確認

```bash
docker volume ls
docker volume inspect inception_wordpress_data inception_mariadb_data
docker inspect wordpress mariadb --format '{{.Name}} {{json .Mounts}}'
```

期待する `Mountpoint`：

```text
/home/mrio/data/docker/volumes/inception_wordpress_data/_data
/home/mrio/data/docker/volumes/inception_mariadb_data/_data
```

`Options` は `null` または空で、`o: bind` や `device` の指定はありません。コンテナ側の `Type` は `volume` です。WordPress と NGINX は前者を `/var/www/html` で共有し、MariaDB は後者を `/var/lib/mysql` で使用します。

通常運用でこの Docker 管理ディレクトリを直接編集しないでください。ファイル操作によるバックアップや復元が必要な場合は、対象サービスを停止し、所有者・権限を保持して行います。

## 以前の Bind Mount を使う構成から移行する場合

1. 投稿・コメント・ユーザーの状態を記録します。現在の Compose、Makefile、Docker 設定も退避します。
2. NGINX と WordPress を停止し、MariaDB を正常にシャットダウンします。
3. 旧 `/home/<LOGIN>/data/wordpress` と `/home/<LOGIN>/data/mariadb` を、`data` の外へ所有者・権限を保持してバックアップします。
4. 旧コンテナを削除し、旧 Named Volume の定義を削除します。旧構成ではボリューム定義を消してもホスト側の元データは残ります。
5. Docker と docker.socket を停止してから、旧 Docker 管理データを新しい `data-root` へコピーし、デーモン設定を変更して起動します。containerd の保存先は変更しません。
6. 通常の Named Volume を作成し、バックアップした WordPress と DB のデータをそれぞれ復元します。**復元はアプリケーションの起動前に行います。**
7. `make` で起動し、ボリュームの `Mountpoint`、サイト表示、管理者ログイン、投稿・コメント・ユーザーの保存を確認します。
8. コンテナを削除して再作成し、データが残ることを確認します。VM 再起動による確認も評価時に行います。

今回の移行バックアップは `/home/mrio/inception-backups/` 配下に保管します。バックアップには認証情報を含む設定や DB が入るため、非公開で管理し、Git に追加しません。元の `/var/lib/docker` と旧データディレクトリは、移行確認が済むまで残します。

参考：[Docker デーモン設定](https://docs.docker.com/engine/daemon/)、[Docker Volumes](https://docs.docker.com/engine/storage/volumes/)。
