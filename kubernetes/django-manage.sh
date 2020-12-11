#!/usr/bin/env zsh

# django の manage.py を実行

command="cd /var/src/myapp && python3 manage.py $@"

export KUBECONFIG=${HOME}/.kube/my-kubeconfig

podname=$(kubectl -n torico get pod -l app=myapp -o jsonpath="{.items[0].metadata.name}")

kubectl -n torico exec -it --container=myapp ${podname} -- /bin/sh -c "${command}"
