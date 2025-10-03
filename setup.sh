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

echo "==> Creating Resource Group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

echo "==> Creating Master VM..."
az vm create --resource-group $RESOURCE_GROUP --name $MASTER_VM \
  --image Ubuntu2204 --size $VM_SIZE \
  --admin-username $ADMIN_USER --generate-ssh-keys --output none

echo "==> Creating Worker VMs..."
az vm create --resource-group $RESOURCE_GROUP --name $WORKER1_VM \
  --image Ubuntu2204 --size $VM_SIZE \
  --admin-username $ADMIN_USER --generate-ssh-keys --output none

az vm create --resource-group $RESOURCE_GROUP --name $WORKER2_VM \
  --image Ubuntu2204 --size $VM_SIZE \
  --admin-username $ADMIN_USER --generate-ssh-keys --output none

echo "==> Opening ports for Kubernetes API on Master..."
az vm open-port --resource-group $RESOURCE_GROUP --name $MASTER_VM --port 6443 --priority 1001 --output none
az vm open-port --resource-group $RESOURCE_GROUP --name $MASTER_VM --port 22 --priority 1002 --output none

# Function to install Kubernetes prerequisites
setup_node() {
  NODE=$1
  echo "==> Setting up Kubernetes prereqs on $NODE..."
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

# Install on all nodes
setup_node $MASTER_VM
setup_node $WORKER1_VM
setup_node $WORKER2_VM

echo "==> Initializing Kubernetes on Master..."
az vm run-command invoke -g $RESOURCE_GROUP -n $MASTER_VM --command-id RunShellScript --scripts "
  sudo kubeadm init --pod-network-cidr=10.244.0.0/16 | tee /home/$ADMIN_USER/kubeinit.log
  mkdir -p /home/$ADMIN_USER/.kube
  sudo cp -i /etc/kubernetes/admin.conf /home/$ADMIN_USER/.kube/config
  sudo chown $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.kube/config
" --output none

echo "==> Fetching join command..."
JOIN_CMD=$(az vm run-command invoke -g $RESOURCE_GROUP -n $MASTER_VM --command-id RunShellScript --scripts "
  grep 'kubeadm join' /home/$ADMIN_USER/kubeinit.log
" --query "value[0].message" -o tsv | tail -1)

echo "Join command is: $JOIN_CMD"

echo "==> Joining Workers to Cluster..."
az vm run-command invoke -g $RESOURCE_GROUP -n $WORKER1_VM --command-id RunShellScript --scripts "sudo $JOIN_CMD" --output none
az vm run-command invoke -g $RESOURCE_GROUP -n $WORKER2_VM --command-id RunShellScript --scripts "sudo $JOIN_CMD" --output none

echo "==> Installing Flannel CNI on Master..."
az vm run-command invoke -g $RESOURCE_GROUP -n $MASTER_VM --command-id RunShellScript --scripts "
  kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
" --output none

echo "==> Kubernetes Cluster Setup Complete!"
echo "Run this to SSH into master and check nodes:"
echo "az ssh vm -g $RESOURCE_GROUP -n $MASTER_VM"
