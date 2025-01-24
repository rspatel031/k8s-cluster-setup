#!/bin/bash

set -e

fancy_echo() {
  local color="$1"
  shift
  echo -e "\033[1;${color}m$*\033[0m"
}

start_setup_banner() {
  fancy_echo 34 "==============================================="
  fancy_echo 34 "      🚀 Starting Kubernetes Worker Setup      "
  fancy_echo 34 "==============================================="
}

# Function to update and upgrade the system
update_system() {
  fancy_echo 32 "🔧 [STEP 1] Updating and upgrading the system..."
  sudo apt update && sudo apt upgrade -y
}

# Function to disable swap
disable_swap() {
  fancy_echo 32 "🔧 [STEP 2] Disabling swap..."
  sudo swapoff -a
  sudo sed -i '/ swap / s/^/#/' /etc/fstab
}

# Function to enable kernel modules and configure sysctl settings
configure_kernel_modules_and_sysctl() {
  fancy_echo 32 "🔧 [STEP 3] Enabling kernel modules and configuring sysctl settings..."
  sudo modprobe overlay
  sudo modprobe br_netfilter

  echo "overlay" | sudo tee /etc/modules-load.d/k8s.conf >/dev/null
  echo "br_netfilter" | sudo tee -a /etc/modules-load.d/k8s.conf >/dev/null

  echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
  echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee -a /etc/sysctl.d/k8s.conf >/dev/null
  echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.d/k8s.conf >/dev/null

  sudo sysctl --system
}

# Function to install and configure containerd
install_and_configure_containerd() {
  fancy_echo 32 "🔧 [STEP 4] Installing and configuring containerd..."
  sudo apt update && sudo apt upgrade -y
  sudo apt-get install -y containerd

  sudo mkdir -p /etc/containerd
  sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

  # Update containerd configuration
  sudo sed -i 's|SystemdCgroup = false|SystemdCgroup = true|' /etc/containerd/config.toml
  sudo sed -i 's|sandbox_image = "registry.k8s.io/pause:3.8"|sandbox_image = "registry.k8s.io/pause:3.10"|' /etc/containerd/config.toml

  # Restart and enable containerd
  sudo systemctl restart containerd
  sudo systemctl enable containerd
}

# Function to configure Kubernetes repositories
configure_kubernetes_repos() {
  fancy_echo 32 "🔧 [STEP 5] Configuring Kubernetes repositories..."
  sudo apt-get install -y apt-transport-https ca-certificates curl gpg
  K8S_LATEST=$(curl -L -s https://dl.k8s.io/release/stable.txt | awk 'BEGIN { FS="." } { printf "%s.%s", $1, $2 }')
  curl -fsSL https://pkgs.k8s.io/core:/stable:/"${K8S_LATEST}"/deb/Release.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_LATEST}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
}

# Function to install Kubernetes components
install_kubernetes_components() {
  fancy_echo 32 "🔧 [STEP 6] Installing Kubernetes components (kubelet, kubeadm)..."
  sudo apt-get update
  sudo apt-get install -y kubelet kubeadm
  sudo apt-mark hold kubelet kubeadm

  # Enable kubelet service
  sudo systemctl enable --now kubelet
}

setup_completed_banner() {
  fancy_echo 32 "✅ [SUCCESS] Kubernetes Worker setup is complete!"
}

# Main script execution
main() {
  start_setup_banner
  update_system
  disable_swap
  configure_kernel_modules_and_sysctl
  install_and_configure_containerd
  configure_kubernetes_repos
  install_kubernetes_components
  setup_completed_banner
}

# Execute the main function
main
