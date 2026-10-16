# Inception レビュー実施手順

添付された評価シートに沿った、日本語の操作手順書です。このリポジトリではログイン名を `mrio`、ドメインを `mrio.42.fr`、Compose のプロジェクト名を `inception` としています。別の学生を評価する場合は読み替えてください。

## 0. 現在の状態と、レビュー前に直すこと

2026-10-16 にファイルと起動中のコンテナを確認しました。

| 項目 | 確認結果・対応 |
| --- | --- |
| `README.md` | 空。冒頭の指定文、Description、Instructions、Resources、AI の利用説明などを記入する必要があります。課題では英語での記述も指定されています。 |
| `USER_DOC.md` | 起動・停止、管理画面、認証情報、保存先の確認手順を記載しています。 |
| `DEV_DOC.md` | data-root の設定、ビルド、Compose 操作、Named Volume と既存データの移行手順を記載しています。 |
| Compose の構文 | 不要な `version` 指定を削除しました。構文は `config --quiet` で確認します。 |
| 既存コンテナ | `make` によるビルド・起動、コンテナ削除後の再作成、サイト表示、管理者ログインを確認しました。ホスト公開は NGINX の 443 のみです。 |
| 永続ストレージ | 通常の Named Volume に移行済みです。`Mountpoint` は `/home/mrio/data/docker/volumes/` 配下、`Options` は `null` です。投稿・コメント・ユーザーが移行前と一致することを確認しました。 |
| `.env` | 現在の `main` の追跡ファイル・履歴にはありません。ローカルファイルとして用意する必要があります。 |
| MariaDB 起動スクリプト | `service mariadb start` で一度デーモンを起動します。評価シートの「entrypoint 内でバックグラウンド起動しない」という条件との整合性を見直してください。 |
| 再起動時の DB 認証 | スクリプト内の `mariadb -e` は認証なしです。root パスワード設定済みのデータで再起動した際にも初期化処理が成功するか確認が必要です。 |
| WordPress 初期化 | DB の起動完了待ちがなく、`wp-config.php` があると初期化を省略します。初回に DB 接続で失敗すると、設定ファイルだけ残って再試行されない可能性があります。 |

**添付の評価シートでは、必須ドキュメントの不足・空ファイルは評価中止の条件です。先に修正してください。この手順書は、それらの必須ドキュメントの代わりにはなりません。**

以下は評価用の手順です。ストレージ移行時にはサービスの停止・再作成と Docker デーモンの再起動を行いました。VM 自体の再起動と、評価シートの全リソース削除コマンドは実行していません。

## 1. 本人・提出物・作業環境を確認する

学生本人が同席し、その学生の VM 上で実施します。評価対象は公式に提出された Git リポジトリです。不正の疑いは、落ち着いて確認し、評価シートの手続きに従います。

```bash
# コマンドの差し替えや、不審な設定がないかを一緒に確認
type -a git docker make
alias
git config --show-origin --get-regexp '^alias\.'
```

Git alias が未設定の場合、最後のコマンドの終了コードが 1 になることは正常です。

空のディレクトリへ、提出先の URL から clone します。以下の URL が公式の提出先と一致することを先に確認してください。

```bash
REVIEW_PARENT=$(mktemp -d /tmp/inception-review.XXXXXX)
git clone https://github.com/Rio-M666/inception.git "$REVIEW_PARENT/inception"
cd "$REVIEW_PARENT/inception"
git remote -v
git log -1 --oneline
git status --short
```

期待結果：提出リポジトリ・コミットが一致し、作業ツリーがクリーンであること。

### 機密情報の確認

```bash
git ls-files
git ls-files -- .env srcs/.env
git log HEAD --oneline -- .env srcs/.env
```

- パスワードや API キーが追跡ファイル・提出履歴に入っていないか、コードを一緒に確認します。ファイル名の確認だけでは検出しきれません。
- 上記の `.env` に関する 2 コマンドは、この提出履歴では何も表示しない想定です。
- `.env` は評価環境でローカルに用意します。パスワード値を画面共有・議事録・Git に載せないでください。
- `git log --all` はローカルの退避ブランチも含みます。提出履歴の確認には `HEAD` を指定します。
- `docker compose config` や `docker inspect` の全出力には環境変数の値が含まれる場合があります。構文確認には `config --quiet` を使います。

## 2. ディレクトリとドキュメントを確認する

```bash
find srcs -maxdepth 5 -type f ! -name '.env' -print
ls -l Makefile README.md USER_DOC.md DEV_DOC.md
wc -c README.md USER_DOC.md DEV_DOC.md
head -n 1 README.md
```

確認する内容：

- 設定ファイルがルート直下の `srcs/` にまとまっている。
- ルートに `Makefile` がある。
- README の最初の行が、斜体の指定文になっている。
- README に Description / Instructions / Resources と AI 利用の説明がある。
- 課題本文の要求する、VM と Docker、Secrets と環境変数、Docker network と host network、volume と bind mount の比較も説明されている。
- `USER_DOC.md`・`DEV_DOC.md` が存在し、必要な説明が書かれている。

README の先頭行の例：

```markdown
*This project has been created as part of the 42 curriculum by mrio.*
```

## 3. Dockerfile・Compose・起動スクリプトを読む

```bash
cat Makefile
cat srcs/docker-compose.yml
find srcs -name Dockerfile -print -exec cat {} \;
cat srcs/requirements/mariadb/tools/mariadb.sh
cat srcs/requirements/wordpress/tools/setup.sh
cat srcs/requirements/nginx/conf/nginx.conf
cat srcs/requirements/wordpress/conf/www.conf
cat srcs/requirements/mariadb/conf/50-server.cnf
```

| 確認項目 | 合格条件 |
| --- | --- |
| Dockerfile | 3 サービスそれぞれに空でない Dockerfile がある |
| ベース | Debian または Alpine の最新から 1 つ前の安定版。`latest` は使わない |
| 自作イメージ | 完成済みの nginx / wordpress / mariadb イメージを `FROM` していない。Debian / Alpine のベース取得は許可 |
| イメージ名 | `nginx` / `wordpress` / `mariadb` と、サービス名が一致する |
| 起動方法 | サービス本体がフォアグラウンドで動く。`exec`、PID 1、シグナル伝達を説明できる |
| 禁止設定 | `network_mode: host`、`network: host`、`links:`、`--link` がない |
| 禁止起動 | `tail -f`、`sleep infinity`、`while true`、単なるシェル待機、バックグラウンド起動でコンテナを維持する処理がない |
| ネットワーク | Compose に `networks` があり、3 サービスが接続される |
| ポート | ホスト公開は NGINX の `443:443` のみ |
| サービス分離 | WordPress と MariaDB のイメージに NGINX が入っていない |
| 再起動 | 異常終了時の restart 設定がある |

`while ! mysqladmin ping ...` は起動完了を待つ条件付きループで、コンテナ維持用の `while true` とは目的が異なります。ただし、起動失敗時に待ち続ける問題と、バックグラウンド起動の有無は別に確認します。

このリポジトリのベースは `debian:bookworm` です。確認時の Debian 公式一覧は stable が Debian 13 / trixie、oldstable が Debian 12 / bookworm です。評価当日にも [Debian 公式リリース一覧](https://www.debian.org/releases/index.en.html) で確認してください。

## 4. 初回起動の準備と、評価シート指定のクリーンアップ

### ローカル設定

学生が `srcs/.env` をローカルに用意します。現在のスクリプトで参照する変数は次のとおりです。

```text
LOGIN
DOMAIN_NAME
MYSQL_DATABASE
MYSQL_USER
MYSQL_PASSWORD
MYSQL_ROOT_PASSWORD
SITE_TITLE
ADMIN_USER
ADMIN_PASSWORD
ADMIN_EMAIL
USER1_NAME
USER1_EMAIL
USER1_PASS
```

`LOGIN=mrio`、サイト URL は `https://mrio.42.fr` と整合させます。管理者名に、大文字・小文字を問わず `admin` を含めてはいけません。値の内容はローカルで確認し、`chmod 600 srcs/.env` で権限を制限します。

ブラウザを動かすマシンの hosts 設定で `mrio.42.fr` が VM の IP を指すようにします。

```bash
# VM の IP を確認
hostname -I

# ブラウザを動かす Linux マシンで確認
getent hosts mrio.42.fr
```

VM 内のブラウザなら VM 内の hosts を、ホスト PC のブラウザならホスト PC の hosts を設定します。後者で `127.0.0.1` を使えるのは、ポート転送を設定している場合です。

### Docker の保存先

初回は [DEV_DOC.md](DEV_DOC.md) に従い、`srcs/docker/daemon.json` を使ってホストの Docker デーモンを設定します。`docker info --format '{{.DockerRootDir}}'` が `/home/mrio/data/docker` を表示することを確認してください。`.env` の `LOGIN` 変更だけではデーモン設定は変わりません。既存データがある環境では、先にバックアップと移行が必要です。

### 全 Docker リソースの削除：評価用 VM でのみ実施

**次のコマンドは Inception 以外も含め、接続先 Docker エンジンのコンテナ・イメージ・ボリューム・ネットワークを削除します。`docker context show` と `docker context inspect` で接続先を確認し、評価用 VM の Docker エンジンに接続していることを確かめてから実行してください。**

評価シートが指定するコマンド：

```bash
docker stop $(docker ps -qa); docker rm $(docker ps -qa); docker rmi -f $(docker images -qa); docker volume rm $(docker volume ls -q); docker network rm $(docker network ls -q) 2>/dev/null
```

対象が空の場合の引数不足や、組み込みネットワークを削除できない旨のエラーが出ることがあります。削除後の状態も確認してください。

```bash
docker ps -a
docker images
docker volume ls
docker network ls
```

通常の Named Volume を使う現在の構成では、`docker volume rm` によって保存データも削除されます。全削除テストの前に必要なバックアップを取り、「既存データからの起動」と「空のデータからの初期構築」を区別してください。

**`make fclean` と `make re` はプロジェクトの Named Volume と保存データを削除します。永続化テスト中には使わないでください。Docker の管理ディレクトリ自体を削除する処理はありません。**

## 5. Makefile からビルド・起動する

以後のコマンドは、clone したリポジトリのルートで実行します。Compose の引数を統一するために、Bash で次の関数を定義します。

```bash
dc() {
  docker compose --project-name inception --env-file srcs/.env -f srcs/docker-compose.yml "$@"
}

dc config --quiet
make
dc ps -a
dc images
dc logs --tail=100
```

期待結果：

- Makefile が Docker の保存先を確認し、Compose で自作イメージをビルドする。
- 3 サービスが起動する。`Exited` や `Restarting` のままにならない。
- サイトへのアクセスまで成功する。`Up` の表示だけで初期化成功と判断しない。
- イメージ名が各サービス名と一致する。

ログに機密値が出た場合は、その値をレビュー記録に転記しないでください。

## 6. Docker の基礎を口頭で説明する

| 質問 | 説明の要点 |
| --- | --- |
| Docker は何をするか | イメージから、プロセス・ネットワーク・ファイルシステムなどが隔離されたコンテナを実行する。Linux コンテナはホストのカーネルを共有する |
| Compose は何をするか | 複数サービスのビルド・起動・ネットワーク・ボリューム・依存関係を YAML で定義し、まとめて操作する |
| Compose の有無でイメージは変わるか | イメージ自体の仕組みは同じ。Compose はビルド方法や起動時の構成をまとめて管理する |
| VM との違いは何か | VM はゲスト OS とカーネルを持つ。コンテナはカーネルを共有し、一般に起動や資源使用の負担が小さい。この課題では VM 上で Docker を使う |
| なぜこのディレクトリ構成か | ルートの Makefile を操作の入口にし、`srcs` に Compose とサービス別のビルド・設定・初期化処理をまとめる |
| PID 1 と `exec` の意味は何か | コンテナ内のプロセス管理や停止シグナルに関係する。`exec` はシェルを起動対象のプロセスに置き換える |

## 7. Docker ネットワークを確認する

```bash
docker network ls
docker network inspect inception_inception
dc exec nginx getent hosts wordpress
dc exec wordpress getent hosts mariadb
```

期待結果：

- 通常、この構成では `inception_inception` という bridge ネットワークができる。
- inspect の接続先に 3 コンテナがある。
- サービス名で相手の IP を名前解決できる。
- `wordpress:9000` は PHP-FPM、`mariadb:3306` は DB への内部接続先であり、ホストへのポート公開は不要と説明できる。

## 8. NGINX・HTTPS・TLS を確認する

### 公開ポートと設定

```bash
dc ps
docker port nginx
docker port wordpress
docker port mariadb
dc exec nginx nginx -t
dc exec nginx nginx -T
```

期待結果：公開ポートは NGINX の 443 のみ。`9000/tcp` と表示されても、`0.0.0.0:9000->...` のようなホスト公開がなければ公開ポートではありません。設定の `ssl_protocols` は `TLSv1.2 TLSv1.3` です。

### HTTP と HTTPS

```bash
# 失敗することを確認。HTTP から HTTPS へのリダイレクトも想定しない
curl -I --connect-timeout 5 http://mrio.42.fr

# 自己署名証明書なので、この確認では -k を付ける
curl -kI --connect-timeout 5 https://mrio.42.fr
```

ブラウザで `https://mrio.42.fr/` を開きます。自己署名証明書の警告を確認して進み、設定済みの WordPress が表示されることを確認します。WordPress のインストール画面が出たら不合格です。

### TLS の実際のネゴシエーション

```bash
openssl s_client -connect mrio.42.fr:443 -servername mrio.42.fr -tls1_2 -brief </dev/null
openssl s_client -connect mrio.42.fr:443 -servername mrio.42.fr -tls1_3 -brief </dev/null
```

期待結果：それぞれ TLSv1.2 / TLSv1.3 でハンドシェイクできること。自己署名による検証エラーと、ハンドシェイク自体の失敗は区別します。「TLS のバージョン」は接続プロトコルの話で、証明書そのもののバージョンとは異なります。

## 9. WordPress・ユーザー・WordPress 用ボリュームを確認する

### インストールとユーザー

```bash
dc exec wordpress wp core is-installed --allow-root
dc exec wordpress wp option get home --allow-root
dc exec wordpress wp option get siteurl --allow-root
dc exec wordpress wp user list --fields=ID,user_login,roles --allow-root
```

期待結果：インストール済みで、URL が公開ドメインと一致すること。管理者と一般ユーザーがいて、管理者名に `admin` を含まないこと。

### ブラウザで実施する操作

1. `https://mrio.42.fr/wp-login.php` で、一般ユーザーとしてログインする。
2. コメントを許可した公開記事を開き、識別しやすいコメント（例：`review-comment-20261016`）を投稿する。
3. 承認が必要なら管理者として承認し、記事ページにコメントが表示されることを確認する。
4. 管理者として `https://mrio.42.fr/wp-admin/` を開く。
5. 「固定ページ」から既存ページを開き、本文に識別用の文字列（例：`review-persistence-20261016`）を追記して「更新」する。
6. そのページの公開 URL を開き、追記が見えることを確認する。
7. コメントした記事 URL と、変更した固定ページ URL を控える。再起動後に同じものを確認する。

コメント欄がない場合は、管理画面で対象記事のディスカッション設定を確認し、学生と一緒にコメント可能な記事を用意します。

### ボリューム

```bash
docker volume ls
docker volume inspect inception_wordpress_data
docker inspect wordpress --format '{{json .Mounts}}'
docker inspect nginx --format '{{json .Mounts}}'
```

期待結果：

- WordPress の `/var/www/html` が `inception_wordpress_data` に接続されている。
- NGINX も同じボリュームを `/var/www/html` に接続している。
- volume inspect の `Mountpoint` が `/home/mrio/data/docker/volumes/inception_wordpress_data/_data` である。
- コンテナ側のマウント種別が `volume` になっている。

この構成では追加の driver options を使わず、通常の Named Volume を作成します。`Options` は `null` または空で、`o: bind` や `device` の指定はありません。Docker の `data-root` を `/home/mrio/data/docker` に設定することで、`Mountpoint` 自体が課題の指定パス配下になります。

## 10. MariaDB・データ・DB 用ボリュームを確認する

```bash
dc ps mariadb
docker volume inspect inception_mariadb_data
docker inspect mariadb --format '{{json .Mounts}}'
dc exec mariadb mariadb -u root -p
```

最後のコマンドは対話式でパスワードを入力します。`-p実際のパスワード` のように、コマンド行に値を書かないでください。

MariaDB のプロンプトで、次を実行します。

```sql
SHOW DATABASES;
-- 次の wordpress は MYSQL_DATABASE に設定した実際の DB 名に読み替える
USE wordpress;
SHOW TABLES;
SELECT COUNT(*) FROM wp_users;
SELECT ID, post_title, post_type FROM wp_posts LIMIT 10;
SELECT comment_ID, comment_content FROM wp_comments ORDER BY comment_ID DESC LIMIT 5;
EXIT;
```

テーブル接頭辞を変更している場合は、`wp_` を実際の接頭辞に置き換えます。

期待結果：

- WordPress 用 DB が存在し、空ではない。
- WordPress のテーブル・ユーザー・投稿データが入っている。
- 前の手順で作ったコメントが、承認待ちも含め DB に保存されている。
- `Mountpoint` が `/home/mrio/data/docker/volumes/inception_mariadb_data/_data`、接続先が `/var/lib/mysql` である。`Options` に bind 指定がない。
- 学生が接続方法、DB 名、アプリ用ユーザーと root の役割を説明できる。

## 11. VM の再起動で永続化を確認する

**コンテナの restart だけでは、評価シートの VM 再起動テストの代わりになりません。**

1. コメントと固定ページの変更が表示されることを確認し、URL を控える。
2. VM 内で次を実行する。SSH 接続中なら切断されるので、起動後に再接続する。

```bash
sudo reboot
```

3. VM 再起動後、同じ clone 先のルートへ戻る。
4. 手順 5 の `dc` 関数をもう一度定義し、次を実行する。

```bash
dc up -d
dc ps -a
dc logs --tail=100
```

5. 同じサイトを開き、インストール画面が出ないことを確認する。
6. 管理者でログインし、前のコメントと固定ページの変更が残っていることを確認する。
7. DB 接続とボリュームの保存先も再確認する。

この途中で `make re`・`make fclean`・データディレクトリの削除をすると、永続化を確認できません。

## 12. その場で設定変更する例：PHP-FPM を 9000 → 9001 にする

評価者が対象サービスと変更内容を指定します。以下は、外部公開の 443 を維持したまま、WordPress の内部待受ポートを変更する練習例です。実際の指定が別の内容なら、その依存先も調べて対応します。

### 変更前

```bash
git status --short
dc exec wordpress sh -c 'ss -lnt 2>/dev/null || cat /proc/net/tcp'
```

9001 が別の設定・サービスに使われていないことを確認します。`ss` がない場合、`/proc/net/tcp` のポートは 16 進数表示です（9000 は `2328`、9001 は `2329`）。

### 変更するファイル

| ファイル | 変更前 | 変更後 |
| --- | --- | --- |
| `srcs/requirements/wordpress/conf/www.conf` | `listen = 9000` | `listen = 9001` |
| `srcs/requirements/nginx/conf/nginx.conf` | `fastcgi_pass wordpress:9000;` | `fastcgi_pass wordpress:9001;` |
| `srcs/requirements/wordpress/Dockerfile` | `EXPOSE 9000` | `EXPOSE 9001` |

`EXPOSE` は説明用のメタデータです。実際の待受は PHP-FPM の `listen` が決めるため、`EXPOSE` だけを変えても動作は変わりません。NGINX の転送先も同時に変更する理由を説明します。

### 再ビルド・再起動・検証

```bash
git diff -- srcs/requirements/wordpress/conf/www.conf srcs/requirements/nginx/conf/nginx.conf srcs/requirements/wordpress/Dockerfile
make
dc ps -a
dc exec wordpress php-fpm8.2 -tt
dc exec nginx nginx -t
dc exec wordpress sh -c 'ss -lnt 2>/dev/null || cat /proc/net/tcp'
curl -kI https://mrio.42.fr
dc logs --tail=50 nginx wordpress
```

期待結果：PHP-FPM が 9001 で待受し、NGINX がそこへ転送する。ブラウザで WordPress、ログイン、変更済みページまで確認し、502 エラーが出ないことを確認します。

確認後は、上記 3 箇所を元の値へ戻して `make` し、通常の 443 から再確認します。無関係な編集を消すような `git reset --hard` は不要です。

## 13. 問題が出たときに見る場所

| 症状 | 確認するもの |
| --- | --- |
| ドメインが見つからない | ブラウザ側の hosts、VM の IP、VM のネットワーク方式 |
| HTTPS に接続できない | `dc ps -a`、443 の公開、VM のポート転送・ファイアウォール、NGINX のログ |
| 502 Bad Gateway | WordPress の起動、PHP-FPM の listen、NGINX の fastcgi_pass、サービス名解決 |
| DB 接続エラー | MariaDB の起動とログ、DB 名・ユーザー・認証、初期化順序 |
| WordPress のインストール画面 | 初期化ログ、DB のテーブル、`wp core is-installed`、途中失敗した `wp-config.php` |
| ログイン時に別 URL へ移動する | `wp option get home` / `siteurl`、ブラウザ側の名前解決 |
| 再起動後にデータが見えない | 同じ Compose プロジェクト・ボリュームか、`LOGIN` と device のパス、データ削除の有無 |
| コンテナが Up なのに機能しない | スクリプトの途中失敗が見逃されていないか。ログと実際の HTTP / DB 操作を確認 |

## 14. 最終チェックリスト

- [ ] 本人同席・正しい提出リポジトリを空の場所へ clone した
- [ ] 追跡ファイル・提出履歴に認証情報がない
- [ ] README・USER_DOC・DEV_DOC が必要な内容を満たす
- [ ] 配置・Dockerfile・ベース版・禁止設定を確認した
- [ ] Makefile から自作イメージをビルドし、3 サービスが起動した
- [ ] Docker / Compose / VM / ネットワーク / PID 1 を説明できる
- [ ] ネットワークとサービス名での名前解決を確認した
- [ ] 公開は 443 のみで、HTTP 接続はできない
- [ ] TLS 1.2 / 1.3 と、設定済み WordPress の表示を確認した
- [ ] 一般ユーザーでコメントし、管理者で固定ページを更新した
- [ ] 2 ボリュームと `/home/mrio/data/` の保存先を確認した
- [ ] DB にログインし、テーブル・データを確認した
- [ ] VM 再起動後もユーザー・コメント・ページ変更が残った
- [ ] 指定された設定変更後、再ビルドして機能することを示した

根拠：添付の Inception 評価シート、リポジトリ内の [課題日本語訳](subject/inception-ja.md)、[課題 PDF](subject/inception.pdf)。解釈が分かれる場合は、その評価で使う原文と評価シートを照合してください。
