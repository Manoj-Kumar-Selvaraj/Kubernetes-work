---

# 🚀 Kubernetes Cluster Setup on Azure with Shell Script

This guide explains how the provided shell script automates the setup of a **3-node Kubernetes cluster** (1 master + 2 workers) on **Azure Virtual Machines**.

The script uses:

* **Azure CLI** (`az`) for provisioning infrastructure
* **kubeadm** for bootstrapping Kubernetes
* **Flannel** as the CNI (Container Networking Interface) plugin

---

## 📝 Script Breakdown

### 1. Variables

```bash
RESOURCE_GROUP="k8s-lab-rg"
LOCATION="eastus"
MASTER_VM="k8s-master"
WORKER1_VM="k8s-worker1"
WORKER2_VM="k8s-worker2"
VM_SIZE="Standard_B2s"
ADMIN_USER="azureuser"
```

* **RESOURCE_GROUP** → logical container for all Azure resources.
* **LOCATION** → Azure region (e.g., `eastus`).
* **MASTER_VM / WORKER VMs** → names of VMs.
* **VM_SIZE** → Azure instance type (`Standard_B2s` = 2 vCPU, 4 GB RAM).
* **ADMIN_USER** → Linux admin username for all VMs.

---

### 2. Create Resource Group

```bash
az group create --name $RESOURCE_GROUP --location $LOCATION
```

👉 Creates an Azure resource group where all VMs and networking resources will live.

---

### 3. Create VMs

```bash
az vm create --resource-group $RESOURCE_GROUP --name $MASTER_VM \
  --image Ubuntu2204 --size $VM_SIZE \
  --admin-username $ADMIN_USER --generate-ssh-keys --output none
```

* Creates **Ubuntu 22.04** VMs (1 master + 2 workers).
* Generates SSH keys automatically for login.
* `--output none` suppresses extra output for cleaner logs.

---

### 4. Open Required Ports

```bash
az vm open-port --resource-group $RESOURCE_GROUP --name $MASTER_VM --port 6443 --priority 1001 --output none
az vm open-port --resource-group $RESOURCE_GROUP --name $MASTER_VM --port 22 --priority 1002 --output none
```

* **Port 6443** → Kubernetes API server (workers need this to talk to the master).
* **Port 22** → SSH access.
* Equivalent to **adding inbound rules in AWS Security Groups**.

---

### 5. Install Kubernetes Prerequisites

The function `setup_node()` installs required packages on each VM:

```bash
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo bash -c 'cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF'
sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl containerd
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable containerd
sudo systemctl start containerd
```

* **kubelet** → runs on all nodes, manages pods.
* **kubeadm** → bootstraps the cluster.
* **kubectl** → CLI to interact with Kubernetes.
* **containerd** → container runtime.

The function is run for **master and workers**:

```bash
setup_node $MASTER_VM
setup_node $WORKER1_VM
setup_node $WORKER2_VM
```

---

### 6. Initialize Master Node

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 | tee /home/$ADMIN_USER/kubeinit.log
```

* Initializes the Kubernetes **control plane**.
* Uses Flannel’s default CIDR for pod networking.
* Saves logs to `/home/azureuser/kubeinit.log`.

Then:

* Creates kubeconfig for the user (`~/.kube/config`) so you can run `kubectl`.

---

### 7. Fetch Worker Join Command

```bash
JOIN_CMD=$(az vm run-command invoke ... grep 'kubeadm join' /home/$ADMIN_USER/kubeinit.log)
```

* Extracts the **`kubeadm join`** command from the master logs.
* Example join command:

  ```bash
  kubeadm join <MASTER_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
  ```

---

### 8. Join Workers to Cluster

```bash
az vm run-command invoke ... "sudo $JOIN_CMD"
```

* Runs the join command on **worker1** and **worker2**, attaching them to the cluster.

---

### 9. Install Flannel CNI

```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

* Sets up pod networking (so pods across nodes can talk to each other).

---

### 10. Completion

```bash
echo "==> Kubernetes Cluster Setup Complete!"
```

* Finally, it prints how to SSH into the master:

  ```bash
  az ssh vm -g $RESOURCE_GROUP -n $MASTER_VM
  ```

From there you can verify:

```bash
kubectl get nodes
```

Expected output:

```
NAME          STATUS   ROLES           AGE   VERSION
k8s-master    Ready    control-plane   XXm   v1.xx.x
k8s-worker1   Ready    <none>          XXm   v1.xx.x
k8s-worker2   Ready    <none>          XXm   v1.xx.x
```

---

## ✅ Summary

This script does:

1. Creates **3 Ubuntu VMs** in Azure.
2. Opens firewall ports (22, 6443).
3. Installs Kubernetes packages on all nodes.
4. Initializes the master with `kubeadm init`.
5. Auto-extracts the join command.
6. Adds workers with `kubeadm join`.
7. Installs Flannel for networking.
8. Produces a working **multi-node Kubernetes cluster**.

---
