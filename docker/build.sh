#!/usr/bin/env zsh

cd "$(dirname $0)" || exit

. ./config.sh

cd ..

docker build . --ssh default -t ${image_name} -f docker/Dockerfile
