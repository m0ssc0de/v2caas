#!/bin/bash

# yum install nfs-utils 
# apt-get install nfs-common

kubectl apply -f ./src/common.yaml
kubectl apply -f ./src/provisioner.yaml
kubectl apply -f ./src/operator.yaml
# TODO: check and verify
kubectl -n rook-nfs-system get pod

kubectl apply -f ./src/rbac.yaml
# TODO: config size of the pool
kubectl apply -f ./src/nfs-server.yaml
# TODO: check and verify
kubectl -n rook-nfs get pod

kubectl apply -f ./src/sc.yaml
# TODO: check and verify
kubectl get sc

# Test
kubectl apply -f test-pvc.yaml