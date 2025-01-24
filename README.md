# Kubernetes Cluster Setup

This guide provides a step-by-step process for setting up a Kubernetes cluster with:
- A **Control Plane** node.
- One or more **Worker Nodes**.

Two scripts are included:
1. **`control-plane.sh`**: For setting up the control plane.
2. **`worker-node.sh`**: For setting up the worker nodes.

Both setups include detailed instructions and port configurations for various network add-ons like Calico, Weave, and Flannel.

---

## Prerequisites

1. You have at least two machines (VMs or physical) with Ubuntu installed (22.04 or later is recommended).
2. You have root or sudo access to these machines.
3. Networking is properly configured between the nodes.
4. Swap is disabled on all nodes.

---

## Installation Overview

### Script 1: Setting Up the Control Plane
1. Copy the `control-plane.sh` script to your control plane node.
2. Make the script executable:
   ```bash
   chmod +x control-plane.sh
   ```
3. Run the script:
   ```bash
   sudo ./control-plane.sh

### Output:
At the end of the script, you will receive a **join command** for worker nodes. This is stored at:
```bash
/tmp/kubeadm-init-output.txt
```

---

### Script 2: Setting Up Worker Nodes
**Important:** Ensure you set the hostname before executing the worker-node.sh script.

The **`worker-node.sh`** script prepares worker nodes and joins them to the cluster.

### Steps:

1. Copy the `worker-node.sh` script to your worker node(s).
2. Make the script executable:
   ```bash
   chmod +x worker-node.sh
   ```
3. Run the script:
   ```bash
   sudo ./worker-node.sh
   ```
4. Once the script finishes, use the **join command** from the control plane node to connect the worker node to the cluster. For example:
   ```bash
   sudo kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
   ```
---

## Script Breakdown

### Control Plane Script (`control-plane.sh`)
The control plane script:
1. Updates and upgrades the system.
2. Sets the hostname to `control-plane`.
3. Disables swap for Kubernetes compatibility.
4. Configures required kernel modules and `sysctl` settings.
5. Installs and configures `containerd`.
6. Configures Kubernetes repositories.
7. Installs Kubernetes components (`kubelet`, `kubeadm`, and `kubectl`).
8. Initializes the Kubernetes control plane.
9. Sets `crictl` endpoints.
10. Deploys a default network add-on.
11. Displays the `kubeadm init` command output.
12. Adds `kubectl` aliases and autocompletion for ease of use.

### Worker Node Script (`worker-node.sh`)
The worker node script:
1. Updates and upgrades the system.
2. Disables swap.
3. Configures required kernel modules and `sysctl` settings.
4. Installs and configures `containerd`.
5. Configures Kubernetes repositories.
6. Installs Kubernetes components (`kubelet` and `kubeadm`).

---

## Network Add-Ons

Kubernetes requires a network add-on to manage communication between pods. Below are the supported network add-ons with their corresponding configuration files:

- **Calico**:
  ```bash
  wget https://raw.githubusercontent.com/rspatel031/k8s-network-addons/refs/heads/main/calico/calico.yaml
  ```
- **Flannel**:
  ```bash
  wget https://raw.githubusercontent.com/rspatel031/k8s-network-addons/refs/heads/main/flannel/flannel.yaml
  ```
- **Weave**:
  ```bash
  wget https://raw.githubusercontent.com/rspatel031/k8s-network-addons/refs/heads/main/weave/weave.yaml
  ```

**CIDR Configuration:** All network add-ons mentioned above are preconfigured to use the `10.244.0.0/16` CIDR range.

---

## Port Requirements

Below are the port details required for the cluster to function properly:

### Kubernetes Components
| Component          | Protocol | Ports      | Description                           |
|--------------------|----------|------------|---------------------------------------|
| Kube-API Server    | TCP      | 6443       | Kubernetes API server port.           |
| etcd               | TCP      | 2379-2380  | Communication between etcd members.   |
| Kubelet            | TCP      | 10250      | Worker node to API server communication. |
| Kube Scheduler     | TCP      | 10251      | Scheduler communication.              |
| Kube Controller    | TCP      | 10252      | Controller-manager communication.     |

### Network Add-Ons
| Add-On  | Protocol | Ports      | Description                               |
|---------|----------|------------|-------------------------------------------|
| Calico  | TCP/UDP  | 179        | BGP communication between nodes.         |
| Flannel | UDP      | 8285       | Overlay network communication.           |
| Flannel | UDP      | 8472       | VXLAN communication.                     |
| Weave   | TCP/UDP  | 6783-6784  | Control plane and data plane traffic.    |

---

## Additional Notes

- Ensure ports are open and accessible between nodes in the cluster.
- Ensure you use the correct `kubeadm join` command on worker nodes.
- The scripts are written for Ubuntu and may require modifications for other distributions.
- The **control-plane** setup also deploys a Weave Net network add-on. You can customize the network plugin if needed.
- Restart nodes if necessary after installation.
- Use the provided configuration files to deploy any network add-on suitable for your environment.

---

## References

- [Calico Configuration](https://raw.githubusercontent.com/rspatel031/k8s-network-addons/refs/heads/main/calico/calico.yaml)
- [Flannel Configuration](https://raw.githubusercontent.com/rspatel031/k8s-network-addons/refs/heads/main/flannel/flannel.yaml)
- [Weave Configuration](https://raw.githubusercontent.com/rspatel031/k8s-network-addons/refs/heads/main/weave/weave.yaml)
