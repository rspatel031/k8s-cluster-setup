#!/bin/bash

set -e

fancy_echo() {
  local color="$1"
  shift
  echo -e "\033[1;${color}m$*\033[0m"
}

start_setup_banner() {
  fancy_echo 34 "==========================================="
  fancy_echo 34 "      🚀 Starting Kubernetes Setup         "
  fancy_echo 34 "==========================================="
}

# Function to update and upgrade the system
update_system() {
  fancy_echo 32 "🔧 [STEP 1] Updating and upgrading the system..."
  sudo apt update && sudo apt upgrade -y
}

# Function to set the hostname
set_hostname() {
  local hostname="control-plane"
  fancy_echo 32 "🔧 [STEP 2] Setting hostname to ${hostname}..."
  sudo hostnamectl set-hostname "$hostname"
}

# Function to disable swap
disable_swap() {
  fancy_echo 32 "🔧 [STEP 3] Disabling swap..."
  sudo swapoff -a
  sudo sed -i '/ swap / s/^/#/' /etc/fstab
}

# Function to enable kernel modules and configure sysctl settings
configure_kernel_modules_and_sysctl() {
  fancy_echo 32 "🔧 [STEP 4] Enabling kernel modules and configuring sysctl settings..."
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
  fancy_echo 32 "🔧 [STEP 5] Installing and configuring containerd..."
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
  fancy_echo 32 "🔧 [STEP 6] Configuring Kubernetes repositories..."
  sudo apt-get install -y apt-transport-https ca-certificates curl gpg
  K8S_LATEST=$(curl -L -s https://dl.k8s.io/release/stable.txt | awk 'BEGIN { FS="." } { printf "%s.%s", $1, $2 }')
  curl -fsSL https://pkgs.k8s.io/core:/stable:/"${K8S_LATEST}"/deb/Release.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_LATEST}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
}

# Function to install Kubernetes components
install_kubernetes_components() {
  fancy_echo 32 "🔧 [STEP 7] Installing Kubernetes components (kubelet, kubeadm, kubectl)..."
  sudo apt-get update
  sudo apt-get install -y kubelet kubeadm kubectl
  sudo apt-mark hold kubelet kubeadm kubectl

  # Enable kubelet service
  sudo systemctl enable --now kubelet
}

# Function to initialize Kubernetes control plane
initialize_kubernetes() {
  fancy_echo 32 "🔧 [STEP 8] Initializing Kubernetes control plane..."
  sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --upload-certs | sudo tee /tmp/kubeadm-init-output.txt

  # Configure kubectl for the current user
  mkdir -p "$HOME"/.kube
  sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
  sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config
}

# Function to configure crictl endpoints
set_crictl_end_point() {
  fancy_echo 32 "🔧 [STEP 9] Configuring crictl endpoints..."
  sudo crictl config \
    --set runtime-endpoint=unix:///run/containerd/containerd.sock \
    --set image-endpoint=unix:///run/containerd/containerd.sock
}

# Function to deploy the network add-on
deploy_network_addon() {
  fancy_echo 32 "🔧 [STEP 10] Deploying network add-on..."
  kubectl apply -f https://raw.githubusercontent.com/rspatel031/k8s-network-addon/refs/heads/main/weave/weave.yaml
}

# Function to display the kubeadm init command output
display_kubeadm_inti_command_output() {
  fancy_echo 33 "==========================================="
  fancy_echo 33 "🔑 Kubeadm init command output stored at /tmp/kubeadm-init-output.txt"
  fancy_echo 33 "==========================================="
}

setup_completed_banner() {
  fancy_echo 32 "✅ [SUCCESS] Kubernetes setup is complete!"
}

setup_kubectl_alias_and_completion() {
  local shell_config_file

  # Detect the shell and corresponding config file
  if [[ "$SHELL" == */bash ]]; then
    shell_config_file="$HOME/.bashrc"
  else
    fancy_echo 31 "⚠️ Unsupported shell: $SHELL. Please add manually."
    return 1
  fi

  fancy_echo 32 "🔧 Adding kubectl alias and auto-completion to $shell_config_file..."

  # Ensure kubectl completion script is sourced
  grep -qxF 'source <(kubectl completion bash)' "$shell_config_file" || echo 'source <(kubectl completion bash)' >>"$shell_config_file"

  # Add alias for kubectl
  grep -qxF 'alias k="kubectl"' "$shell_config_file" || echo 'alias k="kubectl"' >>"$shell_config_file"

  # Add alias completion for kubectl
  grep -qxF 'complete -F __start_kubectl k' "$shell_config_file" || echo 'complete -F __start_kubectl k' >>"$shell_config_file"

  # Reload the shell configuration
  source "$shell_config_file"

  fancy_echo 34 "✅ Kubectl alias and completion added successfully!"
  fancy_echo 33 "🔄 Please restart your terminal or run: source $shell_config_file"
}

# Main script execution
main() {
  start_setup_banner
  update_system
  set_hostname
  disable_swap
  configure_kernel_modules_and_sysctl
  install_and_configure_containerd
  configure_kubernetes_repos
  install_kubernetes_components
  initialize_kubernetes
  set_crictl_end_point
  deploy_network_addon
  display_kubeadm_inti_command_output
  setup_completed_banner
  setup_kubectl_alias_and_completion
}

# Execute the main function
main
