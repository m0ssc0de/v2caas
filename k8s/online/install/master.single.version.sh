#!/bin/bash

set -eux

kubeadm init --pod-network-cidr=192.186.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f https://docs.projectcalico.org/v3.14/manifests/calico.yaml