#!/usr/bin/env bash

# mac で実行すると pod を削除して再起動する

export KUBECONFIG=${HOME}/.kube/my-kubeconfig

podname=$(kubectl -n torico get pod -l app=myapp -o jsonpath="{.items[0].metadata.name}")

kubectl -n torico delete pod ${podname}
