#!/usr/bin/env zsh

# mac で実行すると pod にリモートログインする

export KUBECONFIG=${HOME}/.kube/my-kubeconfig

podname=$(kubectl -n torico get pod -l app=myapp -o jsonpath="{.items[0].metadata.name}")

kubectl -n torico exec -it ${podname} -- /bin/sh
