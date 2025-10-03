#!/bin/bash
set -e

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
# Function: Create VM if not exists
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

# -----------------------------
# Create master and worker VMs
# -----------------------------
create_vm_if_not_exists $MASTER_VM
create_vm_if_not_exists $WORKER1_VM
create_vm_if_not_exists $WORKER2_VM

# -----------------------------
# Open ports for Kubernetes API and SSH
# -----------------------------
echo "==> Opening ports 6443 (K8s API) and 22 (SSH) on Master..."
az vm open-port --resource-group $RESOURCE_GROUP --name $MASTER_VM --port 6443 --priority 1001 --output none || true
az vm open-port --resource-group $RESOURCE_GROUP --name $MASTER_VM --port 22 --priority 1002 --output none || true

# -----------------------------
# Function: Setup Kubernetes prerequisites
# -----------------------------
setup_node() {
    NODE=$1
    echo "==> Installing Kubernetes prerequisites on $NODE..."
    az vm run-command invoke -g $RESOURCE_GROUP -n $NODE --command-id RunShellScript --scripts "
        sudo apt-get update -y
        sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee /etc/apt/sources.list.d/kubernetes.list
        sudo apt-get update -y
        sudo apt-get install -y kubelet kubeadm kubectl containerd
        sudo apt-mark hold kubelet kubeadm kubectl
        sudo systemctl enable kubelet containerd
        sudo systemctl start containerd
    " --output json
}

# -----------------------------
# Install Kubernetes on all nodes
# -----------------------------
setup_node $MASTER_VM
setup_node $WORKER1_VM
setup_node $WORKER2_VM

# -----------------------------
# Initialize Kubernetes on Master
# -----------------------------
echo "==> Initializing Kubernetes on Master..."
JOIN_CMD=$(az vm run-command invoke -g $RESOURCE_GROUP -n $MASTER_VM --command-id RunShellScript --scripts "
    if [ ! -f /home/$ADMIN_USER/kubeinit.log ]; then
        sudo kubeadm init --pod-network-cidr=10.244.0.0/16 | tee /home/$ADMIN_USER/kubeinit.log
    fi
    cat /home/$ADMIN_USER/kubeinit.log | grep 'kubeadm join'
" --query "value[0].message" -o tsv)

echo "==> kubeadm join command captured:"
echo "$JOIN_CMD"

# -----------------------------
# Join worker nodes
# -----------------------------
for NODE in $WORKER1_VM $WORKER2_VM; do
    echo "==> Joining $NODE to the cluster..."
    az vm run-command invoke -g $RESOURCE_GROUP -n $NODE --command-id RunShellScript --scripts "
        sudo $JOIN_CMD || echo '$NODE might already be joined'
    " --output json
done

# -----------------------------
# Install Flannel CNI on Master
# -----------------------------
echo "==> Installing Flannel CNI on Master..."
az vm run-command invoke -g $RESOURCE_GROUP -n $MASTER_VM --command-id RunShellScript --scripts "
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml || echo 'Flannel already installed'
" --output json

echo "==> Kubernetes Cluster Setup Complete!"
echo "==> SSH into Master to check nodes: az ssh vm -g $RESOURCE_GROUP -n $MASTER_VM"
