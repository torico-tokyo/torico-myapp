
docker-compose を 使っての PyCharm でのリモートデバッグ実行

docker-compose の環境変数デフォルト値の設定

# ディレクトリ構成

+ app
  + manage.py
  + myapp
    + settings
      + local.py
      + production.py
+ uwsgi
  + uwsgi.ini
+ docker
  + docker-compose.yml
  + Dockerfile
  + build.sh
  + config.sh
  + run.sh
+ kubernetes
  + apply.sh
  + deployment.yml
  + service.yml


# docker

## dockerビルド・実行方法
```zsh
docker/build.sh
docker/run.sh
```
ブラウザで  http://127.0.0.1:8000 を開くと、Django のランディングページが表示されます。


## ディレクトリ内容

```zsh:docker/config.sh
image_name=torico/myapp
container_name=myapp
```
共通で使う、Docker イメージ名などを定義しています。

```zsh:docker/build.sh
#!/usr/bin/env zsh
cd "$(dirname $0)" || exit
. ./config.sh
cd ..
docker build . --ssh default -t ${image_name} -f docker/Dockerfile
```
Dockerfile をプロジェクトルートに入れず、docker ディレクトリの中に入れてますが、
ビルド対象はプロジェクトルートのため、一回上位ディレクトリに移動してからビルドしてます。

`--ssh` オプション、および  `Dockerfile` の1行目の
`# syntax=docker/dockerfile:1.0.0-experimental`
は、Pipfile から Python のプライベートリポジトリのライブラリをインストールする時に使います。
プライベートリポジトリのライブラリが無い場合は必要ありません。

### Dockerfile

```Dockerfile
# syntax=docker/dockerfile:1.0.0-experimental

FROM alpine:3.12

ENV PYTHONUNBUFFERED 1

RUN apk --no-cache add \
    python3 \
    py3-pip \
    uwsgi \
    uwsgi-http \
    uwsgi-python3 \
    mariadb-connector-c \
    git \
    openssh \
    jpeg

RUN pip3 install pipenv --ignore-installed distlib

COPY Pipfile /tmp/Pipfile

RUN apk add --no-cache --virtual=.build-deps \
    gcc \
    make \
    python3-dev \
    musl-dev \
    libffi-dev \
    mariadb-dev \
    postgresql-dev \
    g++ \
    libgcc \
    libstdc++ \
    libxml2-dev \
    libxslt-dev \
    jpeg-dev \
    && PIPENV_PIPFILE=/tmp/Pipfile pipenv install --dev --system --skip-lock --deploy \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/*

RUN mkdir -m 777 -p /var/log/myapp

COPY uwsgi /var/src/uwsgi
COPY app /var/src/app
RUN chown -R uwsgi:uwsgi /var/src

USER uwsgi
RUN cd /var/src/app && python3 ./manage.py collectstatic --noinput

EXPOSE 8000
CMD ["uwsgi", "--ini", "/var/src/uwsgi/uwsgi.ini"]
```
ライブラリを多く盛り込んでいます。今回のように、ただ Django を起動するだけではこれらのライブラリは
必要ありませんが、 PIL、ソーシャルログイン、HTMLパーサー、mysqlclient、firebase、
もろもろ Pipenv に追加していくと、ビルドのためのライブラリが必要になります。

今回のように、必要ライブラリをすべて入れてビルドする以外にも、
ビルドが必要なライブラリは Pipenv ではインストールせず、
ビルド済みライブラリをインストールする方法であったり、
ビルドを行うにしてもマルチステージの Dockerfile を作って行う方法もありますが、
Alpine では `apk --virtual=` でのインストールが、
Dockerfile を簡潔に保てて良いと感じており、よく使います。

Dockerイメージ単体で(ボリュームのマウントなしで)起動するようにするため、
Djangoのソースコードをコピーして含めています。
Admin などで static ディレクトリを使うため、Dockerビルド段階で collectstatic を実行しておきます。

なお、Alpine Linux にはロケールデータが無いため、国際化 i10n, i18n は難しいです。
国際化が必要な場合は、debian を使うのが楽だと思います。

参考までに、マルチステージビルドを行った場合の (別プロジェクトで使っている) Dockerfile も載せます。

```Dockerfile
FROM alpine:3.12 AS builder
# マルチステージビルドを試してみたが、campaignfox などでやってるような
# apk --virtual をつかう手法と比べてイメージサイズを少なくできるわけではない。
# --virtual のほうが dockerfile が短くできるので、そっちがいいかな。

RUN apk --no-cache add \
  python3 \
  py3-pip

RUN pip3 install pipenv --ignore-installed distlib

COPY Pipfile /tmp/Pipfile

RUN apk add --no-cache --virtual=.build-deps \
  gcc \
  make \
  python3-dev \
  musl-dev \
  libffi-dev \
  mariadb-dev \
  postgresql-dev \
  g++ \
  libgcc \
  libstdc++ \
  libxml2-dev \
  libxslt-dev \
  jpeg-dev \
  && PIPENV_PIPFILE=/tmp/Pipfile pipenv install --system --skip-lock --deploy \
  && apk del .build-deps \
  && rm -rf /var/cache/apk/* \
  && rm -rf /tmp/*


FROM alpine:3.12

COPY --from=builder /usr/lib/python3.8/site-packages /usr/lib/python3.8/

RUN apk --no-cache add \
  git \
  python3 \
  py3-pip \
  musl \
  uwsgi \
  uwsgi-http \
  uwsgi-python3 \
  mariadb-connector-c \
  libxml2 \
  libxslt \
  py3-pillow

# py3-pillow は、画像のライブラリをインストールするため

RUN mkdir -m 777 -p /var/log/awesome-app

COPY conf /var/src/conf
COPY awesome_app /var/src/awesome_app
RUN chown -R uwsgi:uwsgi /var/src

USER uwsgi
RUN cd /var/src/awesome_app && python3 ./manage.py collectstatic --noinput

EXPOSE 8080
CMD ["uwsgi", "--ini", "/var/src/conf/uwsgi.ini"]
```


## PyCharm からのデバッグ方法
新しい mac は、Python 3.9 がデフォルトでインストールされており、
そのままでは Python 3.8 の Python 仮想環境 (.venv)
を作ることができません。

brew で pyenv をインストールして、pyenv 内でダウングレードバージョンの
Python を管理するのも良いのですが、Pycharm は docker でのデバッグ実行も可能です。

docker でのデバッグ実行をする際は、docker イメージのバージョンをファイルで管理したほうが簡潔なため、
docker-compose 経由での起動がおすすめです。

### PyCharm での Python Interpreter の指定
`⌘+,` → Python Interpreter → Add

`Docker Compose` → `New` → `Docker for mac`

`Configuration file(s)` に、`docker/docker-compose.yml` を指定

`Service` に `myapp` を指定

`Python interpreter path:` は、`python` から `python3` に変更しておく。

Alpine linux では、python コマンドでは python3 が起動できないためです。

設定したら `[OK]` をクリック。

すると、先程作った Docker イメージを認識して、Python3.8環境が使えるようになります。

Path mappings も設定します。

プロジェクト内の `django` ディレクトリが、`/var/src/app` にマッピングされるようにします。

### PyCharm での Project Structure の設定

`⌘+,` → Project Structure

Django ディレクトリを Sources に追加

### PyCharm での Django Support の設定
`⌘+,` → Django

`Enable Django Support` にチェック

`Django project root` は、`django` ディレクトリ

`Settings` には、`myapp/settings/local.py` を設定

### 実行コンフィギュレーションの作成

右上の、`Edit Configurations` より
`+` → `Django Server` → `Host` に `0.0.0.0` を指定して、環境を作ります。

Python Interpreter は、先程設定した Docker compose になっているはずです。

虫ボタンからデバッグ実行すると、docker-compose で起動した Python へリモートデバッグが行えます。

## docker-compose.yml の解説

```yaml
version: '3'

services:
  myapp:
    image: torico/myapp
    container_name: myapp
    ports:
      - "8000:8000"
    environment:
      DJANGO_SETTINGS_MODULE: ${DJANGO_SETTINGS_MODULE:-myapp.settings.local}
    restart: always
    volumes:
      - ../app:/var/src/app
```

```yaml
DJANGO_SETTINGS_MODULE: ${DJANGO_SETTINGS_MODULE:-myapp.settings.local}
```
docker compose version 3 より、環境変数のデフォルト値が使えるようになっています。

この場合は、環境変数 `DJANGO_SETTINGS_MODULE` が設定されていなければ、
`myapp.settings.local` を使うという設定になります。

そのため、

```
DJANGO_SETTINGS_MODULE=myapp.settings.development docker-compose up -d
```
といった、環境を切り替えてのDjango の起動も容易です。

```yaml
    volumes:
      - ../app:/var/src/app
```

Dockerファイルで、app ディレクトリをまるごとコピーしてイメージを作っていますが、
docker-compose から起動した際はホストのディレクトリを docker イメージのディレクトリを上書きする形でマウントしています。
開発のためです。

# uwsgi
冒頭で、
```zsh
docker/build.sh
docker/run.sh
```
のコマンドで Django サーバを起動したり、後述の kuberneters で起動する際は、
webアプリケーションサーバとして uwsgi が起動します。

uwsgi の設定ファイルは以下の形ですが
```ini:uwsgi.ini
[uwsgi]
base = /var/src/app
chdir = %(base)

plugins = http,python3
http = 0.0.0.0:8000
vacuum = true
die-on-term = true

module = myapp.wsgi:application
master = true

if-not-env = DJANGO_SETTINGS_MODULE
env = DJANGO_SETTINGS_MODULE=myapp.settings.local
endif =

env = LC_ALL=en_US.UTF-8
env = LANG=en_US.UTF-8
touch-reload = %(base)/myapp/wsgi.py
uid = uwsgi
static-map = /static=/var/src/staticfiles
logto = /var/log/myapp/%n.log
thunder-lock = true
buffer-size = 32768
processes = %k
threads = 16
```

ポイントとしては
```ini
if-not-env = DJANGO_SETTINGS_MODULE
env = DJANGO_SETTINGS_MODULE=myapp.settings.local
endif =
```
ここで、もし環境変数 `DJANGO_SETTINGS_MODULE` がセットされていなければ。
デフォルト値を使うようにしています。

kubernetes で起動する際、settings を外から指定できるようにするためです。

```
processes = %k
```
は、コア数をそのまま使っています。

外部通信 (DB, ElasticSearch, Redis, メール, ログ) が多かったりして
待機時間が多いアプリの場合は、並列で多くのリクエストを扱えるよう、threads は多めにしています。

検証環境は少なめ、本番環境は多めにするため

```
threads = %(%k * 10)
```
といった設定にすることもあります。(コア数の10倍)

# kubernetes
作ったイメージは、EKS にプッシュして kubernetes にデプロイします。

mac で、kubernetes/apply.sh を実行して、本番環境を構築します。

```yaml
#!/usr/bin/env zsh

export KUBECONFIG=${HOME}/.kube/my-kubeconfig

kubectl apply -f deployment.yml
kubectl apply -f service.yml
kubectl apply -f ingress.yml
```

予め、 kubernetes クラスタの kubeconfig を、mac の ${HOME}/.kube/my-kubeconfig
としてコピーしておき、そのパスを環境変数 KUBECONFIG に設定することで、
本番クラスタを操作できます。

便宜上、今回のマニフェストは

```yaml
containers:
  - name: myapp
    image: torico/myapp
    imagePullPolicy: Never
```

としており、ローカルの docker イメージを使う設定となっていますが、実際はECR からプルするため

```yaml
containers:
  - name: manga-master
    image: 000000000.dkr.ecr.ap-northeast-1.amazonaws.com/torico/myapp
    imagePullPolicy: Always
```
となります。

これは EKS を想定していますが、EKS ではなく独自にクラスタを立てている場合は

```yaml
containers:
  - name: manga-master
    image: 000000000.dkr.ecr.ap-northeast-1.amazonaws.com/torico/myapp
    imagePullPolicy: Always
imagePullSecrets:
  - name: ecr-credeintial
```

のようにして、ecr-credential を作る時は、python スクリプトでこのように作っています。

(`aws ecr get-login` の結果を、`kubectl create secret` する)

```python3
#!/usr/bin/env python3

import subprocess

namespace = 'torico'
secret_name = 'ecr-credeintial'
aws_region = 'ap-northeast-1'
docker_server = 'https://00000000.dkr.ecr.ap-northeast-1.amazonaws.com'


def main():
    output = subprocess.check_output([
        '/snap/bin/aws', 'ecr', 'get-login',
        '--no-include-email', '--region', aws_region,
    ]).decode()
    words = output.split()
    username = words[words.index('-u') + 1]
    password = words[words.index('-p') + 1]

    command = [
        '/snap/bin/kubectl', '-n', namespace, 'delete',  'secret', secret_name]
    subprocess.run(command)

    command = [
        '/snap/bin/kubectl', '-n', namespace, 'create', 'secret',
        'docker-registry', secret_name,
        f'--docker-username={username}',
        f'--docker-password={password}',
        f'--docker-server={docker_server}'
    ]
    subprocess.run(command)


if __name__ == '__main__':
    main()
```
