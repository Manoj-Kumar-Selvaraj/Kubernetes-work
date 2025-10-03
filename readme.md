
---

### **1. Kubernetes Architecture Terms**

| Term                   | Explanation                                                                                                                                              |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Cluster**            | A set of machines (nodes) running Kubernetes, managing your containerized applications.                                                                  |
| **Control Plane**      | The brain of the cluster. Manages cluster state, scheduling, and API requests. Runs components like API Server, Scheduler, Controller Manager, and etcd. |
| **Worker Node**        | Machines that run application workloads (Pods). Each has a kubelet, kube-proxy, and container runtime.                                                   |
| **etcd**               | Distributed key-value store storing all cluster state and configuration.                                                                                 |
| **API Server**         | Exposes Kubernetes API. All `kubectl` commands go through it.                                                                                            |
| **Scheduler**          | Assigns Pods to Nodes based on resource availability and constraints.                                                                                    |
| **Controller Manager** | Ensures the cluster matches the desired state (e.g., maintains replica counts).                                                                          |
| **kubelet**            | Agent on each node, ensures containers described in PodSpecs are running.                                                                                |
| **kube-proxy**         | Handles network routing for Services to direct traffic to correct Pods.                                                                                  |

---

### **2. Pods & Deployments**

| Term                | Explanation                                                                                      |
| ------------------- | ------------------------------------------------------------------------------------------------ |
| **Pod**             | Smallest deployable unit in Kubernetes. Can have one or more containers sharing storage/network. |
| **Container**       | Runs the actual app inside a Pod. Usually Docker or another OCI container.                       |
| **ReplicaSet (RS)** | Ensures a specified number of Pod replicas are running at all times.                             |
| **Deployment**      | Manages ReplicaSets. Provides updates, rollbacks, and scaling.                                   |
| **Rolling Update**  | Gradually replaces old Pods with new ones without downtime.                                      |
| **Scaling**         | Adjusting number of Pod replicas up or down.                                                     |

---

### **3. Services & Networking**

| Term             | Explanation                                                                                     |
| ---------------- | ----------------------------------------------------------------------------------------------- |
| **Service**      | Stable network endpoint for a set of Pods. Allows communication between Pods and outside world. |
| **ClusterIP**    | Default Service type. Only accessible within cluster.                                           |
| **NodePort**     | Exposes Service on a port on all nodes. Can access outside via `<NodeIP>:<Port>`.               |
| **LoadBalancer** | Provisions cloud load balancer (AWS ELB, Azure LB) for external access.                         |
| **DNS**          | Kubernetes provides internal DNS for Services (e.g., `nginx.default.svc.cluster.local`).        |

---

### **4. Ingress & Ingress Controller**

| Term                   | Explanation                                                                                                |
| ---------------------- | ---------------------------------------------------------------------------------------------------------- |
| **Ingress**            | API object to manage external HTTP/HTTPS access to Services. Can route based on hostname/path.             |
| **Ingress Controller** | Watches Ingress resources and configures load balancer/proxy accordingly. (e.g., NGINX Ingress Controller) |

---

### **5. ConfigMaps & Secrets**

| Term          | Explanation                                                                                            |
| ------------- | ------------------------------------------------------------------------------------------------------ |
| **ConfigMap** | Stores non-sensitive config data (e.g., app settings) and injects into Pods as env variables or files. |
| **Secret**    | Stores sensitive data (passwords, tokens). Injected into Pods securely.                                |

---

### **6. StatefulSets & DaemonSets**

| Term            | Explanation                                                                                   |
| --------------- | --------------------------------------------------------------------------------------------- |
| **StatefulSet** | Manages Pods that require persistent identity, stable network, and storage (e.g., databases). |
| **DaemonSet**   | Ensures a copy of a Pod runs on all/selected nodes (e.g., log collector, monitoring agent).   |

---

### **7. Persistent Volumes & Storage**

| Term                              | Explanation                                                                            |
| --------------------------------- | -------------------------------------------------------------------------------------- |
| **Persistent Volume (PV)**        | Cluster resource representing storage (network disk, cloud volume).                    |
| **Persistent Volume Claim (PVC)** | Request by a Pod for storage. Kubernetes binds PVC to a PV.                            |
| **StorageClass**                  | Defines types of storage (fast SSD, networked storage) and dynamic provisioning rules. |

---

### **8. RBAC & Security Basics**

| Term                | Explanation                                                         |
| ------------------- | ------------------------------------------------------------------- |
| **RBAC**            | Role-Based Access Control, controls who can do what in the cluster. |
| **Role**            | Set of permissions within a namespace.                              |
| **ClusterRole**     | Permissions across the whole cluster.                               |
| **RoleBinding**     | Assigns Role to a user or service account in a namespace.           |
| **Service Account** | Identity for Pods to access Kubernetes API.                         |

---

### **9. Resource Management**

| Term                         | Explanation                                          |
| ---------------------------- | ---------------------------------------------------- |
| **Requests**                 | Minimum resources a Pod needs to schedule on a node. |
| **Limits**                   | Maximum resources a Pod can use.                     |
| **Namespaces**               | Virtual clusters inside one cluster for isolation.   |
| **Quality of Service (QoS)** | Determines Pod priority based on Requests/Limits.    |

---

### **10. Probes & Health Checks**

| Term                | Explanation                                                                    |
| ------------------- | ------------------------------------------------------------------------------ |
| **Liveness Probe**  | Checks if app is alive; restarts Pod if failed.                                |
| **Readiness Probe** | Checks if Pod is ready to serve traffic; removes from Service if failed.       |
| **Startup Probe**   | Delays liveness probes until app fully starts (useful for slow-starting apps). |

---

### **11. Debugging & Troubleshooting**

| Term                 | Explanation                                     |
| -------------------- | ----------------------------------------------- |
| **kubectl logs**     | Shows logs of a container in a Pod.             |
| **kubectl describe** | Shows detailed info/events of a resource.       |
| **kubectl exec**     | Run commands inside a Pod container.            |
| **CrashLoopBackOff** | Pod keeps crashing; check logs/events to debug. |

---

### **12. Network Policies**

| Term               | Explanation                                                                                           |
| ------------------ | ----------------------------------------------------------------------------------------------------- |
| **Network Policy** | Controls allowed traffic between Pods. Can allow/block traffic based on labels, namespaces, or ports. |

---

## **1. Cluster & Nodes**

| Concept       | Command / Example                   | Notes                                                    |
| ------------- | ----------------------------------- | -------------------------------------------------------- |
| Get nodes     | `kubectl get nodes`                 | Shows all nodes with status, roles, age, version         |
| Node details  | `kubectl get nodes -o wide`         | Shows IP, OS, kernel, pods running                       |
| Node describe | `kubectl describe node <node-name>` | Detailed node info (allocatable resources, pods, events) |

---

## **2. Pods, ReplicaSets & Deployments**

| Concept           | Command / Example                                       | Notes                                                     |
| ----------------- | ------------------------------------------------------- | --------------------------------------------------------- |
| Get pods          | `kubectl get pods`                                      | List all pods in default namespace                        |
| Pod details       | `kubectl describe pod <pod-name>`                       | Check events, containers, volumes, status                 |
| Create deployment | `kubectl create deployment nginx --image=nginx`         | Creates a deployment with 1 replica                       |
| Get deployments   | `kubectl get deployments`                               | Shows deployments with replica status                     |
| Scale deployment  | `kubectl scale deployment nginx --replicas=3`           | Increase/decrease replicas                                |
| Rolling update    | `kubectl set image deployment/nginx nginx=nginx:latest` | Update image without downtime                             |
| Delete pod        | `kubectl delete pod <pod-name>`                         | Pod will be recreated by ReplicaSet if part of Deployment |

---

## **3. Services & Networking**

| Concept               | Command / Example                                               | Notes                                            |
| --------------------- | --------------------------------------------------------------- | ------------------------------------------------ |
| Expose pod as service | `kubectl expose deployment nginx --type=NodePort --port=80`     | Exposes pod externally                           |
| Get services          | `kubectl get svc`                                               | Shows ClusterIP, NodePort, LoadBalancer services |
| NodePort access       | `curl <NodeIP>:<NodePort>`                                      | Test external access                             |
| LoadBalancer          | `kubectl expose deployment nginx --type=LoadBalancer --port=80` | Cloud only (AWS, Azure)                          |

---

## **4. Ingress & Ingress Controller**

| Concept              | Command / Example                                                                                                                         | Notes                           |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| Deploy NGINX ingress | `kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/cloud/deploy.yaml` | Installs ingress controller     |
| Create ingress       | `kubectl apply -f ingress.yaml`                                                                                                           | Routes HTTP traffic to services |
| Get ingress          | `kubectl get ingress`                                                                                                                     | Shows host/path routing         |
| Describe ingress     | `kubectl describe ingress <name>`                                                                                                         | Details events & routing        |

---

## **5. ConfigMaps & Secrets**

| Concept          | Command / Example                                                      | Notes                           |
| ---------------- | ---------------------------------------------------------------------- | ------------------------------- |
| Create ConfigMap | `kubectl create configmap my-config --from-literal=ENV=dev`            | Can also use `--from-file`      |
| Get ConfigMaps   | `kubectl get configmaps`                                               | Lists config maps               |
| Use in pod       | Add `envFrom: configMapRef: name: my-config` in Pod spec               |                                 |
| Create Secret    | `kubectl create secret generic my-secret --from-literal=password=1234` | Encoded automatically in base64 |
| Get Secrets      | `kubectl get secrets`                                                  | Sensitive info hidden           |

---

## **6. StatefulSets & DaemonSets**

| Concept     | Command / Example                   | Notes                                         |
| ----------- | ----------------------------------- | --------------------------------------------- |
| StatefulSet | `kubectl apply -f statefulset.yaml` | Used for databases (stable network & storage) |
| DaemonSet   | `kubectl apply -f daemonset.yaml`   | One pod per node (e.g., monitoring agent)     |
| Get pods    | `kubectl get pods -o wide`          | Check which nodes pods are running            |

---

## **7. Persistent Volumes & Storage**

| Concept       | Command / Example                           | Notes               |
| ------------- | ------------------------------------------- | ------------------- |
| Create PVC    | `kubectl apply -f pvc.yaml`                 | Requests storage    |
| Get PV & PVC  | `kubectl get pv` / `kubectl get pvc`        | Check bound storage |
| Attach to pod | Add `volume` and `volumeMounts` in pod spec |                     |

---

## **8. RBAC & Security**

| Concept            | Command / Example                                                                  | Notes                      |
| ------------------ | ---------------------------------------------------------------------------------- | -------------------------- |
| Create Role        | `kubectl create role pod-reader --verb=get,list,watch --resource=pods`             | Namespace-scoped           |
| Create ClusterRole | `kubectl create clusterrole pod-reader --verb=get,list,watch --resource=pods`      | Cluster-wide               |
| RoleBinding        | `kubectl create rolebinding pod-reader-binding --role=pod-reader --user=developer` | Grants role to user        |
| Service account    | `kubectl create serviceaccount my-sa`                                              | Pod identity to access API |

---

## **9. Resource Management**

| Concept           | Command / Example                                                                                     | Notes                       |
| ----------------- | ----------------------------------------------------------------------------------------------------- | --------------------------- |
| Pod with limits   | `kubectl run nginx --image=nginx --limits='cpu=500m,memory=256Mi' --requests='cpu=200m,memory=128Mi'` | Controls scheduling & usage |
| Create namespace  | `kubectl create ns test`                                                                              | Isolates resources          |
| Specify namespace | `kubectl get pods -n test`                                                                            | Scoped operations           |

---

## **10. Probes & Health Checks**

| Concept       | Command / Example                                                           | Notes                                        |
| ------------- | --------------------------------------------------------------------------- | -------------------------------------------- |
| Add Liveness  | `livenessProbe: httpGet: path: /healthz port: 8080 initialDelaySeconds: 10` | Restart container if fails                   |
| Add Readiness | `readinessProbe: httpGet: path: /ready port: 8080 initialDelaySeconds: 5`   | Remove from Service if not ready             |
| Startup probe | `startupProbe: httpGet: ...`                                                | Delay liveness checks until app fully starts |

---

## **11. Debugging & Troubleshooting**

| Concept                    | Command / Example                     | Notes                                     |
| -------------------------- | ------------------------------------- | ----------------------------------------- |
| Logs                       | `kubectl logs <pod>`                  | Container logs                            |
| Logs of specific container | `kubectl logs <pod> -c <container>`   | Multi-container pods                      |
| Describe resource          | `kubectl describe pod <pod>`          | Events, container status                  |
| Exec into pod              | `kubectl exec -it <pod> -- /bin/bash` | Run commands inside pod                   |
| Delete pod                 | `kubectl delete pod <pod>`            | Pod recreated if controlled by Deployment |
| CrashLoopBackOff           | Use logs + describe to debug          |                                           |

---

## **12. Network Policies**

| Concept           | Command / Example                         | Notes                            |
| ----------------- | ----------------------------------------- | -------------------------------- |
| Create policy     | `kubectl apply -f netpol.yaml`            | Restrict/allow pod communication |
| Get policies      | `kubectl get networkpolicy`               | Shows applied policies           |
| Test connectivity | `kubectl exec -it <pod> -- curl <target>` | Validate policy rules            |

---

✅ **Tips:**

1. Always check your namespace: `kubectl get pods -A`
2. Use `kubectl apply -f <file.yaml>` for manifests.
3. Use `kubectl get all` to see deployments, services, pods, etc.
4. Debug events with: `kubectl get events --sort-by=.metadata.creationTimestamp`

---

## ✅ Minimum Instance Size (Real World vs Lab)

In a **corporate / production cluster**, the **minimum recommended size** for nodes is usually:

* **vCPUs:** 2–4 vCPUs per node
* **RAM:** 4–8 GB per node
* **Disk:** 50–100 GB (managed SSD, not HDD)
* **OS:** Ubuntu LTS or Azure Linux (RHEL is also common in enterprises)

🔹 For a **learning / lab environment**, you can go smaller:

* **2 vCPU, 4 GB RAM, 30 GB disk** → works fine for Kubernetes basics.

---

## ✅ Cluster Setup on Azure (3 Nodes)

We’ll simulate a **real-world cluster** with:

* **1 Control Plane (Master)** → runs API Server, etcd, controllers.
* **2 Worker Nodes** → where your apps (pods, deployments, services) will run.

### Step 1. Create Resource Group

```bash
az group create --name k8s-lab-rg --location eastus
```

### Step 2. Create 3 VMs (Ubuntu 22.04)

Example (Standard_B2s: 2 vCPUs, 4GB RAM):

```bash
# Master node
az vm create --resource-group k8s-lab-rg --name k8s-master \
  --image Ubuntu2204 --size Standard_B2s \
  --admin-username azureuser --generate-ssh-keys

# Worker nodes
az vm create --resource-group k8s-lab-rg --name k8s-worker1 \
  --image Ubuntu2204 --size Standard_B2s \
  --admin-username azureuser --generate-ssh-keys

az vm create --resource-group k8s-lab-rg --name k8s-worker2 \
  --image Ubuntu2204 --size Standard_B2s \
  --admin-username azureuser --generate-ssh-keys
```

### Step 3. Open Required Ports (for Kubernetes)

```bash
az vm open-port --resource-group k8s-lab-rg --name k8s-master --port 6443 --priority 1001
az vm open-port --resource-group k8s-lab-rg --name k8s-master --port 22 --priority 1002
```

(Workers only need SSH, master needs **6443** for API server communication.)

---

## ✅ Installing Kubernetes (with kubeadm)

On all 3 nodes:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y apt-transport-https ca-certificates curl
sudo curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo bash -c 'cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF'
sudo apt update
sudo apt install -y kubelet kubeadm kubectl containerd
sudo apt-mark hold kubelet kubeadm kubectl
```

---

### Step 4. Initialize Cluster (on Master)

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

After success, it will give you a **kubeadm join command**.
Save it for worker nodes.

Set up kubeconfig on master:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

### Step 5. Install Network Plugin (Weave or Flannel)

Example with Flannel:

```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

---

### Step 6. Join Worker Nodes

Run the **join command** (from Step 4) on both workers.
Example:

```bash
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

---

### Step 7. Verify Cluster

On master:

```bash
kubectl get nodes
```

You should see:

```
NAME           STATUS   ROLES           AGE   VERSION
k8s-master     Ready    control-plane   10m   v1.30.x
k8s-worker1    Ready    <none>          5m    v1.30.x
k8s-worker2    Ready    <none>          5m    v1.30.x
```

---

full shell script:


