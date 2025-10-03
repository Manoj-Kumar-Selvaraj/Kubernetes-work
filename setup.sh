#!/bin/bash
set -e

# Variables
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
          --admin-username $ADMIN_USER --generate-ssh-keys --output none
    else
        echo "==> VM $VM_NAME already exists. Skipping creation."
    fi
}

# Create master and worker VMs
create_vm_if_not_exists $MASTER_VM
create_vm_if_not_exists $WORKER1_VM
create_vm_if_not_exists $WORKER2_VM

# Open required ports for Master VM
echo "==> Opening ports for Kubernetes API and SSH on Master..."
az vm open-port --resource-group $RESOURCE_GROUP --name $MASTER_VM --port 6443 --priority 1001 --output none || true
az vm open-port --resource-group $RESOURCE_GROUP --name $MASTER_VM --port 22 --priority 1002 --output none || true

# Function to setup Kubernetes prerequisites on a node
setup_node() {
    NODE=$1
    echo "==> Setting up Kubernetes prerequisites on $NODE..."
    az vm run-command invoke -g $RESOURCE_GROUP -n $NODE --command-id RunShellScript --scripts "
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
    " --output none
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
" --output none

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
    " --output none
done

# Install Flannel CNI
echo "==> Installing Flannel CNI on Master..."
az vm run-command invoke -g $RESOURCE_GROUP -n $MASTER_VM --command-id RunShellScript --scripts "
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml || echo 'Flannel already installed'
" --output none

echo "==> Kubernetes Cluster Setup Complete!"
echo "Run this to SSH into master and check nodes:"
echo "az ssh vm -g $RESOURCE_GROUP -n $MASTER_VM"
