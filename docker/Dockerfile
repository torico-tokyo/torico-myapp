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
