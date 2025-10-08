#!/bin/bash
set -e

# =========================
# Kubernetes Cluster Setup Script on Azure (Ubuntu 22.04)
# Fully Automated
# =========================

# Variables
RESOURCE_GROUP="k8s-lab-rg"
LOCATION="eastus"
MASTER_VM="k8s-master"
WORKER1_VM="k8s-worker1"
WORKER2_VM="k8s-worker2"
VM_SIZE="Standard_B2s"
ADMIN_USER="azureuser"
LOG_FILE="./k8s_setup.log"

# Logging setup: console + log file
echo "==> Logging output to $LOG_FILE"
exec > >(tee -i $LOG_FILE)
exec 2>&1

# =========================
# Create Resource Group
# =========================
if ! az group show --name $RESOURCE_GROUP &>/dev/null; then
    echo "==> Creating Resource Group $RESOURCE_GROUP..."
    az group create --name $RESOURCE_GROUP --location $LOCATION --output table
else
    echo "==> Resource Group $RESOURCE_GROUP already exists. Skipping..."
fi

# =========================
# Function: Create VM if not exists
# =========================
create_vm_if_not_exists() {
    local VM_NAME=$1
    echo "==> Checking VM $VM_NAME..."
    if ! az vm show -g $RESOURCE_GROUP -n $VM_NAME &>/dev/null; then
        echo "==> Creating VM $VM_NAME..."
        az vm create \
            --resource-group $RESOURCE_GROUP \
            --name $VM_NAME \
            --image Ubuntu2204 \
            --size $VM_SIZE \
            --admin-username $ADMIN_USER \
            --generate-ssh-keys \
            --output table
    else
        echo "==> VM $VM_NAME already exists. Skipping creation."
    fi
}

# Create Master and Worker VMs
create_vm_if_not_exists $MASTER_VM
create_vm_if_not_exists $WORKER1_VM
create_vm_if_not_exists $WORKER2_VM

# =========================
# Open required ports for Master VM
# =========================
echo "==> Opening ports 6443 (K8s API) and 22 (SSH) on Master..."
az vm open-port --resource-group $RESOURCE_GROUP --name $MASTER_VM --port 6443 --priority 1001 --output table || true
az vm open-port --resource-group $RESOURCE_GROUP --name $MASTER_VM --port 22 --priority 1002 --output table || true

# =========================
# Function: Setup Kubernetes prerequisites on a node
# =========================
setup_node() {
    NODE=$1
    echo "==> Installing Kubernetes prerequisites on $NODE..."
    az vm run-command invoke -g $RESOURCE_GROUP -n $NODE \
        --command-id RunShellScript \
        --scripts "
# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Install prerequisites
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

sudo mkdir -p /etc/apt/keyrings

# Add official Kubernetes repo for Ubuntu 22.04
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl containerd
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable containerd
sudo systemctl start containerd
        " --output table
}

# Setup all nodes
setup_node $MASTER_VM
setup_node $WORKER1_VM
setup_node $WORKER2_VM

# =========================
# Initialize Kubernetes on Master (background)
# =========================
echo "==> Initializing Kubernetes on Master in background..."
az vm run-command invoke -g $RESOURCE_GROUP -n $MASTER_VM \
    --command-id RunShellScript \
    --scripts "
# Only initialize if log not exists
if [ ! -f /home/$ADMIN_USER/kubeinit.log ]; then
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16 > /home/$ADMIN_USER/kubeinit.log 2>&1 &
fi
" --output table

# =========================
# Wait for join command to appear
# =========================
echo "==> Waiting for kubeadm join command..."
JOIN_CMD=""
while [[ -z \$JOIN_CMD ]]; do
    sleep 60
    JOIN_CMD=$(az vm run-command invoke -g $RESOURCE_GROUP -n $MASTER_VM \
        --command-id RunShellScript \
        --scripts "grep 'kubeadm join' /home/$ADMIN_USER/kubeinit.log || echo ''" \
        --query "value[0].message" -o tsv | tail -1)
    echo "==> Waiting for kubeadm init to finish..."
done

echo "==> Join command detected: $JOIN_CMD"

# =========================
# Join Worker Nodes to Cluster
# =========================
for NODE in $WORKER1_VM $WORKER2_VM; do
    echo "==> Joining $NODE to cluster..."
    az vm run-command invoke -g $RESOURCE_GROUP -n $NODE \
        --command-id RunShellScript \
        --scripts "sudo $JOIN_CMD || echo '$NODE might already be joined'" \
        --output table
done

# =========================
# Configure kubectl on Master and install Flannel
# =========================
echo "==> Configuring kubectl on Master and installing Flannel..."
az vm run-command invoke -g $RESOURCE_GROUP -n $MASTER_VM \
    --command-id RunShellScript \
    --scripts "
mkdir -p /home/$ADMIN_USER/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/$ADMIN_USER/.kube/config
sudo chown $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.kube/config

kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
" --output table

echo "==> Kubernetes Cluster Setup Complete!"
echo "SSH into Master and verify nodes:"
echo "az ssh vm -g $RESOURCE_GROUP -n $MASTER_VM"
