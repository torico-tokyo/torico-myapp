#!/usr/bin/env zsh

export KUBECONFIG=${HOME}/.kube/my-kubeconfig

kubectl apply -f deployment.yml
kubectl apply -f service.yml
kubectl apply -f ingress.yml
