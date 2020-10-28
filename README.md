## What is v2caas?

`v2caas` is a streamlined Container As A Service plan. The ambition is setting up a simple kubernetes cluster and some necessary service such as storage, monitor and so on.

## Architecture

- docker
- infra-registry
- k8s
- promethuse
- alertmanager
- node-expoter

## logical

1. install docker
2. install registry(if need)
3. install kubeadm kubelet kubectl and so on
4. kubeadm install with custom images
5. install nfs in k8s for k8s
6. install promethus and relate components