#!/bin/bash

set -e

# Update and upgrade the system
sudo apt update && sudo apt upgrade -y

# Set the hostname
sudo hostnamectl set-hostname control-plane

# Disable swap: Kubernetes requires swap to be disabled
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Enable kernel modules and configure sysctl settings
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Update your package list and install containerd.
sudo apt update && sudo apt upgrade -y && apt-get install -y containerd

# Configure containerd as per the Kubernetes requirements
sudo mkdir -p /etc/containerd
sudo containerd config default > /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo sed -i 's|sandbox_image = "registry.k8s.io/pause:3.8"|sandbox_image = "registry.k8s.io/pause:3.10"|' /etc/containerd/config.toml

# Restart containerd to apply changes
sudo systemctl restart containerd
sudo systemctl enable containerd

# Setting kubernetes community-owned repositories v1.32
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install kubeadm, kubelet, and kubectl on all nodes
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Enable the kubelet service before running kubeadm
sudo systemctl enable --now kubelet

# Run kubeadm init on the master node
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --upload-certs

# Configure kubectl for the current user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Deploy a network add ons (calico)
kubectl apply -f https://raw.githubusercontent.com/rspatel031/k8s-network-addons/main/calico/calico.yaml
