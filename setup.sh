#!/bin/bash
set -e

# ================================
# Kubernetes Cluster Setup Script
# Supports Ubuntu 22.04 (Jammy)
# ================================

# Variables
RESOURCE_GROUP="k8s-lab-rg"
LOCATION="eastus"
MASTER_VM="k8s-master"
WORKER1_VM="k8s-worker1"
WORKER2_VM="k8s-worker2"
VM_SIZE="Standard_B2s"
ADMIN_USER="azureuser"
LOG_FILE="./k8s_setup.log"

# Logging
echo "==> Logging output to $LOG_FILE"
exec > >(tee -i $LOG_FILE)
exec 2>&1

# Create resource group if not exists
if ! az group show --name $RESOURCE_GROUP &>/dev/null; then
    echo "==> Creating Resource Group $RESOURCE_GROUP..."
    az group create --name $RESOURCE_GROUP --location $LOCATION
else
    echo "==> Resource Group $RESOURCE_GROUP already exists. Skipping..."
fi

# Function to create VM if it doesn't exist
create_vm_if_not_exists() {
    local VM_NAME=$1
    echo "==> Checking VM $VM_NAME..."
    if ! az vm show -g $RESOURCE_GROUP -n $VM_NAME &>/dev/null; then
        echo "==> Creating VM $VM_NAME..."
        az vm create --resource-group $RESOURCE_GROUP --name $VM_NAME \
          --image Ubuntu2204 --size $VM_SIZE \
          --admin-username $ADMIN_USER --generate-ssh-keys --output json
    else
        echo "==> VM $VM_NAME already exists. Skipping creation."
    fi
}

# Create master and worker VMs
create_vm_if_not_exists $MASTER_VM
create_vm_if_not_exists $WORKER1_VM
create_vm_if_not_exists $WORKER2_VM

# Open required ports for Master VM
echo "==> Opening ports 6443 (K8s API) and 22 (SSH) on Master..."
az vm open-port --resource-group $RESOURCE_GROUP --name $MASTER_VM --port 6443 --priority 1001 --output json || true
az vm open-port --resource-group $RESOURCE_GROUP --name $MASTER_VM --port 22 --priority 1002 --output json || true

# Function to setup Kubernetes prerequisites on a node
setup_node() {
    NODE=$1
    echo "==> Installing Kubernetes prerequisites on $NODE..."
    az vm run-command invoke -g $RESOURCE_GROUP -n $NODE --command-id RunShellScript --scripts "
        sudo apt-get update -y
        sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

        # Add Kubernetes repo for Ubuntu 22.04 (Jammy)
        sudo mkdir -p /etc/apt/keyrings
        sudo curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg

        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-jammy main' | sudo tee /etc/apt/sources.list.d/kubernetes.list

        sudo apt-get update -y
        sudo apt-get install -y kubelet kubeadm kubectl containerd
        sudo apt-mark hold kubelet kubeadm kubectl
        sudo systemctl enable containerd
        sudo systemctl start containerd
    " --output json
}

# Setup all nodes
setup_node $MASTER_VM
setup_node $WORKER1_VM
setup_node $WORKER2_VM

# Initialize Kubernetes on master
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
" --output json

# Fetch join command from master
JOIN_CMD=$(az vm run-command invoke -g $RESOURCE_GROUP -n $MASTER_VM --command-id RunShellScript --scripts "
    grep 'kubeadm join' /home/$ADMIN_USER/kubeinit.log
" --query "value[0].message" -o tsv | tail -1)

echo "==> Join command: $JOIN_CMD"

# Join worker nodes to cluster
for NODE in $WORKER1_VM $WORKER2_VM; do
    echo "==> Joining $NODE to cluster..."
    az vm run-command invoke -g $RESOURCE_GROUP -n $NODE --command-id RunShellScript --scripts "
        sudo $JOIN_CMD || echo '$NODE might already be joined'
    " --output json
done

# Install Flannel CNI
echo "==> Installing Flannel CNI on Master..."
az vm run-command invoke -g $RESOURCE_GROUP -n $MASTER_VM --command-id RunShellScript --scripts "
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml || echo 'Flannel already installed'
" --output json

echo "==> Kubernetes Cluster Setup Complete!"
echo "Run this to SSH into master and check nodes:"
echo "az ssh vm -g $RESOURCE_GROUP -n $MASTER_VM"
