# 安装手册

1. 部署 lb
2. 部署 docker，加载本地镜像
3. 部署 k8s
4. 部署监控套件

## 1. 部署 lb

1. 收集三台主节点的 ip(掩码) 和网络接口名。并选出 lb 主节点。
2. 选出虚拟 ip。没有分配的 ip. 
3. 每台机器安装 `haproxy`, `keepalived`。
    1. `apt-get install haproxy keepalived`
4. 配置 `haproxy`。 `/etc/haproxy/haproxy.cfg`

```
global
        log /dev/log    local1 warning
        chroot /var/lib/haproxy
        user haproxy
        group haproxy
        daemon
        maxconn 50000
        nbproc 1

defaults
        log     global
        timeout connect 5s
        timeout client  10m
        timeout server  10m

listen kube-master
        bind 0.0.0.0:8443
        mode tcp
        option tcplog
        option dontlognull
        option dontlog-normal
        balance roundrobin
        server { 主节点1 ip } { 主节点1 ip }:6443 check inter 5s fall 2 rise 2 weight 1
        server { 主节点2 ip } { 主节点2 ip }:6443 check inter 5s fall 2 rise 2 weight 1
        server { 主节点3 ip } { 主节点3 ip }:6443 check inter 5s fall 2 rise 2 weight 1
```

5. 配置 `keepalived`。选主节点的第一台做 `keepalived` 的 master 节点。master 节点和 backup 节点配置略有不同。
    1. `keepalived` master 节点。`/etc/keepalived/keepalived.conf`

```
global_defs {
    router_id lb-master-{ 当前节点 ip }
    script_user root
}

vrrp_script check-haproxy {
    script "/usr/bin/killall -0 haproxy"
    interval 5
    weight -60
}

vrrp_instance VI-kube-master {
    state MASTER
    priority 120
    unicast_src_ip { 当前节点 ip }/{ 掩码长度 }
    unicast_peer {
        { 其他主机点 ip }/{ 掩码长度 }
        { 其他主机点 ip }/{ 掩码长度 }
    }
    dont_track_primary
    interface { 网络接口名 }
    virtual_router_id 222
    advert_int 3
    track_script {
        check-haproxy
    }
    virtual_ipaddress {
        { 虚拟 IP }/{ 掩码长度 }
    }
}
```

    2. `keepalived` backup 节点。`/etc/keepalived/keepalived.conf`

```
global_defs {
    router_id lb-backup-{ 当前节点 ip }
    script_user root
}

vrrp_script check-haproxy {
    script "/usr/bin/killall -0 haproxy"
    interval 5
    weight -60
}

vrrp_instance VI-kube-master {
    state BACKUP
    priority { 小于 120，不重复 }
    unicast_src_ip { 当前节点 ip }/{ 掩码长度 }
    unicast_peer {
        { 其他主机点 ip }/{ 掩码长度 }
        { 其他主机点 ip }/{ 掩码长度 }
    }
    dont_track_primary
    interface { 网络接口名 }
    virtual_router_id 222
    advert_int 3
    track_script {
        check-haproxy
    }
    virtual_ipaddress {
        { 虚拟 IP }/{ 掩码长度 }
    }
}
```

6. 重启，并设置开机启动

三台主机。最好在第一台重启后 `ip addr` 看一下虚拟 ip 是否正常分配，再进行下一台。

```shell
systemctl restart haproxy
systemctl enable haproxy
systemctl restart keepalived
systemctl enable keepalived
```

## 2. 部署 docker，加载镜像

```shell
tar -zxvf docker-pkg.tar.gz
cd docker-pkg
sudo apt-get install ./*
docker ps
```

应该看到空的容器列表

```
cd ..
docker load -i docker-images.tar.gz
```

## 3. 部署 k8s

1. 每台节点

```
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

tar -zxvf kube.tar.gz
cd kube
sudo apt-get install ./*
```

2. 第一台主节点

```
kubeadm init --control-plane-endpoint={ 虚拟 IP }:8443 --pod-network-cidr=192.186.0.0/16 --upload-certs
```

成功后会输出如下文字。请保存在合适位置。其他节点需要

```
To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of the control-plane node running the following command on each as root:

  kubeadm join 172.29.103.90:8443 --token z06xo0.g0d5fi8b61dhedrg \
    --discovery-token-ca-cert-hash sha256:7a7cdba7cf285bc92bfa4415ea8c0fecf34875135cf1e675b6cf079b6c98ca40 \
    --control-plane --certificate-key 19427e69f7539b99393078dfc95f8e2af09aadeb0b1bceb4cd640ca3d79247f3

Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
"kubeadm init phase upload-certs --upload-certs" to reload certs afterward.

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 172.29.103.90:8443 --token z06xo0.g0d5fi8b61dhedrg \
    --discovery-token-ca-cert-hash sha256:7a7cdba7cf285bc92bfa4415ea8c0fecf34875135cf1e675b6cf079b6c98ca40
```

执行

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

安装插件 `kubectl apply -f ./calico.yaml`

之后 `kubectl get nodes --watch` 等待节点 ready

3. 其他主节点

执行上一步保存的命令。通常是三行。类似如下。

```
#  kubeadm join 172.29.103.90:8443 --token z06xo0.g0d5fi8b61dhedrg \
#    --discovery-token-ca-cert-hash sha256:7a7cdba7cf285bc92bfa4415ea8c0fecf34875135cf1e675b6cf079b6c98ca40 \
#    --control-plane --certificate-key 19427e69f7539b99393078dfc95f8e2af09aadeb0b1bceb4cd640ca3d79247f3
```

之后 `kubectl get nodes --watch` 等待节点 ready

4. 剩余节点

执行上一步保存的命令。通常是两行。类似如下。

```
# kubeadm join 172.29.103.90:8443 --token z06xo0.g0d5fi8b61dhedrg \
#    --discovery-token-ca-cert-hash sha256:7a7cdba7cf285bc92bfa4415ea8c0fecf34875135cf1e675b6cf079b6c98ca40
```

之后 `kubectl get nodes --watch` 等待节点 ready

## 4. 部署监控套件

```
cd monitoring
kubectl create -f manifests/setup
```

之后 `kubectl -n monitoring get pods --watch` 等待 pod running

```
kubectl create -f manifests/
```

之后 `kubectl -n monitoring get pods --watch` 等待 pod running

然后 `kubectl -n monitoring get service` 查看套件内各组件的服务地址端口。

## 5. 存储(待定)