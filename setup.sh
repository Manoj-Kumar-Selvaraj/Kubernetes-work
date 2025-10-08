#!/bin/bash
set -e

# =========================
# Kubernetes Cluster Setup Script on Azure (Ubuntu 22.04)
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
HOSTS_FILE="./hosts.ini"

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

# Open SSH for Worker Nodes
for NODE in $WORKER1_VM $WORKER2_VM; do
    echo "==> Opening SSH port 22 on $NODE..."
    az vm open-port --resource-group $RESOURCE_GROUP --name $NODE --port 22 --priority 1001 --output table || true
done

# =========================
# Generate Ansible hosts.ini
# =========================
echo "==> Fetching public IPs for Ansible inventory..."
MASTER_IP=$(az vm list-ip-addresses -g $RESOURCE_GROUP -n $MASTER_VM --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv)
WORKER1_IP=$(az vm list-ip-addresses -g $RESOURCE_GROUP -n $WORKER1_VM --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv)
WORKER2_IP=$(az vm list-ip-addresses -g $RESOURCE_GROUP -n $WORKER2_VM --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv)

cat > $HOSTS_FILE <<EOL
[k8s-master]
$MASTER_IP ansible_user=$ADMIN_USER ansible_ssh_private_key_file=~/.ssh/id_rsa

[k8s-workers]
$WORKER1_IP ansible_user=$ADMIN_USER ansible_ssh_private_key_file=~/.ssh/id_rsa
$WORKER2_IP ansible_user=$ADMIN_USER ansible_ssh_private_key_file=~/.ssh/id_rsa
EOL

echo "==> Ansible inventory saved to $HOSTS_FILE"
echo "==> Setup complete. You can now run your Ansible playbook:"
echo "ansible-playbook -i $HOSTS_FILE k8s-setup.yml"
