#!/usr/bin/env zsh

cd "$(dirname $0)" || exit

. ./config.sh

[ $(docker container ls -a -q -f name=${container_name}) ] && docker rm ${container_name}

docker run \
    --rm -it \
    -p 8000:8000 \
    --env DJANGO_SETTINGS_MODULE=myapp.settings.local \
    --name=${container_name} ${image_name} "$@"
