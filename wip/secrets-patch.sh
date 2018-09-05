#!/bin/bash

set -x

kubectl config set-cluster local --server=https://localhost:6443  --insecure-skip-tls-verify=true

kubectl config set-credentials secret-generator --token=$(kubectl -n uaa get secret $(kubectl -n uaa get secret | grep secret-generator | awk '{print $1}') -o jsonpath="{.data['token']}" | base64 --decode)

kubectl config set-context secret-generator --cluster=local --user=secret-generator --namespace=uaa
kubectl config use-context secret-generator


kubectl patch pod $(kubectl get pods --namespace uaa | awk 'match($0,/secret/){print $1}') -p '{"metadata": {"annotations": {"foo": "bug"}}}'
