#!/bin/bash
set -euo pipefail

# -----------------------------
# Variables
# -----------------------------
RESOURCE_GROUP="k8s-lab-rg"
LOCATION="eastus"
MASTER_VM="k8s-master"
WORKER1_VM="k8s-worker1"
WORKER2_VM="k8s-worker2"
VM_SIZE="Standard_B2s"
ADMIN_USER="azureuser"
LOG_FILE="./k8s_setup.log"

# -----------------------------
# Logging setup
# -----------------------------
echo "==> Logging output to $LOG_FILE"
exec > >(tee -i $LOG_FILE)
exec 2>&1

# -----------------------------
# Create Resource Group if not exists
# -----------------------------
if ! az group show --name $RESOURCE_GROUP &>/dev/null; then
    echo "==> Creating Resource Group $RESOURCE_GROUP..."
    az group create --name $RESOURCE_GROUP --location $LOCATION
else
    echo "==> Resource Group $RESOURCE_GROUP already exists. Skipping..."
fi

# -----------------------------
# Create VM if not exists
# -----------------------------
create_vm_if_not_exists() {
    local VM_NAME=$1
    echo "==> Checking VM $VM_NAME..."
    if ! az vm show -g $RESOURCE_GROUP -n $VM_NAME &>/dev/null; then
        echo "==> Creating VM $VM_NAME..."
        az vm create --resource-group $RESOURCE_GROUP --name $VM_NAME \
            --image Ubuntu2204 --size $VM_SIZE \
            --admin-username $ADMIN_USER --generate-ssh-keys --output none
    else
        echo "==> VM $VM_NAME already exists. Skipping creation."
    fi
}

# Create VMs
create_vm_if_not_exists $MASTER_VM
create_vm_if_not_exists $WORKER1_VM
create_vm_if_not_exists $WORKER2_VM

# -----------------------------
# Open required ports on Master
# -----------------------------
echo "==> Opening ports for Kubernetes API (6443) and SSH (22) on Master..."
az vm open-port --resource-group $RESOURCE_GROUP --name $MASTER_VM --port 6443 --priority 1001 --output none || true
az vm open-port --resource-group $RESOURCE_GROUP --name $MASTER_VM --port 22 --priority 1002 --output none || true

# -----------------------------
# Function to setup Kubernetes prerequisites
# -----------------------------
setup_node() {
    NODE=$1
    echo "==> Setting up Kubernetes prerequisites on $NODE..."
    az vm run-command invoke -g $RESOURCE_GROUP -n $NODE --command-id RunShellScript --scripts "
        set -euxo pipefail

        # Install containerd
        sudo apt-get update -y
        sudo apt-get install -y containerd apt-transport-https ca-certificates curl gnupg lsb-release

        # Configure containerd
        sudo mkdir -p /etc/containerd
        sudo containerd config default | sudo tee /etc/containerd/config.toml
        sudo systemctl restart containerd
        sudo systemctl enable containerd

        # Add Kubernetes apt repository (new way)
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee /etc/apt/sources.list.d/kubernetes.list

        # Install kubelet, kubeadm, kubectl
        sudo apt-get update -y
        sudo apt-get install -y kubelet kubeadm kubectl
        sudo apt-mark hold kubelet kubeadm kubectl
        sudo systemctl enable kubelet
    " --output none
}

# -----------------------------
# Setup all nodes
# -----------------------------
setup_node $MASTER_VM
setup_node $WORKER1_VM
setup_node $WORKER2_VM

# -----------------------------
# Initialize Kubernetes on Master
# -----------------------------
echo "==> Initializing Kubernetes on Master..."
az vm run-command invoke -g $RESOURCE_GROUP -n $MASTER_VM --command-id RunShellScript --scripts "
    if [ ! -f /home/$ADMIN_USER/kubeinit.log ]; then
        sudo kubeadm init --pod-network-cidr=10.244.0.0/16 | tee /home/$ADMIN_USER/kubeinit.log
        mkdir -p /home/$ADMIN_USER/.kube
        sudo cp -i /etc/kubernetes/admin.conf /home/$ADMIN_USER/.kube/config
        sudo chown $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.kube/config
    else
        echo 'Kubernetes already initialized on master. Skipping.'
    fi
" --output none

# -----------------------------
# Fetch join command
# -----------------------------
JOIN_CMD=$(az vm run-command invoke -g $RESOURCE_GROUP -n $MASTER_VM --command-id RunShellScript --scripts "
    grep 'kubeadm join' /home/$ADMIN_USER/kubeinit.log
" --query "value[0].message" -o tsv | tail -1)

echo "==> Join command: $JOIN_CMD"

# -----------------------------
# Join worker nodes
# -----------------------------
for NODE in $WORKER1_VM $WORKER2_VM; do
    echo "==> Joining $NODE to cluster..."
    az vm run-command invoke -g $RESOURCE_GROUP -n $NODE --command-id RunShellScript --scripts "
        sudo $JOIN_CMD || echo '$NODE might already be joined'
    " --output none
done

# -----------------------------
# Install Flannel CNI
# -----------------------------
echo "==> Installing Flannel CNI on Master..."
az vm run-command invoke -g $RESOURCE_GROUP -n $MASTER_VM --command-id RunS
