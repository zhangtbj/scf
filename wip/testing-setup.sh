#!/bin/bash

set -x

kubectl create -f make/assets/caasp-psps.yaml

kubectl create -f normal-user.yaml

kubectl config set-cluster local --server=https://localhost:6443  --insecure-skip-tls-verify=true


kubectl config set-credentials admin --token=$(kubectl -n kube-system get secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}') -o jsonpath="{.items[0].data['token']}" | base64 --decode)

kubectl config set-credentials testing --token=$(kubectl -n testing get secret $(kubectl -n testing get secret | grep testing-user | awk '{print $1}') -o jsonpath="{.data['token']}" | base64 --decode)

kubectl config set-context admin --cluster=local --user=admin
kubectl config set-context testing --cluster=local --user=testing --namespace=testing

kubectl config use-context admin
kubectl get pods --all-namespaces

kubectl config use-context testing
kubectl create -f nginx.yaml
kubectl patch pod nginx -p '{"metadata": {"annotations": {"foo": "bar"}}}'
