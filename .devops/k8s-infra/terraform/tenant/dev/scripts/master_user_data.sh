#!/bin/bash
set -euxo pipefail

# 1. Hostname
hostnamectl set-hostname k8s-master

# 2. Kernel modülleri ve sysctl ayarları
modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# 3. Swap kapatma
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 4. Containerd kurulumu
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y containerd.io

systemctl daemon-reexec
systemctl enable --now containerd

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# SystemdCgroup true yapılır
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd

# 5. Kubeadm, Kubelet, Kubectl kurulumu
apt-get update
apt-get install -y apt-transport-https ca-certificates curl

mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

########################################
# 6. Master Node Kurulumu
########################################
# Private IP adresini al
MASTER_IP=$(hostname -I | awk '{print $1}')

# Kubernetes gerekli container imajlarını çek
kubeadm config images pull

# Master node init
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address="${MASTER_IP}" \
  --control-plane-endpoint="${MASTER_IP}"

########################################
# 7. Kubectl erişimi için config ayarları
########################################

mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

export KUBECONFIG=/home/ubuntu/.kube/config

# Flannel CNI kurulumu
sudo -u ubuntu KUBECONFIG=/home/ubuntu/.kube/config kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Token komutunun hazır olması için kısa bekleme
sleep 20

# Join komutunu sakla
kubeadm token create --print-join-command > /root/kubeadm_join_cmd.sh
chmod +x /root/kubeadm_join_cmd.sh
echo "Worker node eklemek için şu komutu çalıştırın: bash /root/kubeadm_join_cmd.sh"
