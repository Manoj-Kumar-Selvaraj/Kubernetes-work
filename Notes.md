---

# 🧠 Step 1 — Kubernetes Core Concepts (Detailed + Practical)

EKS (Elastic Kubernetes Service) is just **managed Kubernetes** by AWS.

So before touching AWS, we must *deeply* understand what Kubernetes is and how it works.

---

## 🧩 1. What is Kubernetes?

Kubernetes (K8s) is a **container orchestration system** that automates:

* **Deployment** (starting your containers)
* **Scaling** (adding/removing instances automatically)
* **Self-healing** (restarts crashed containers)
* **Load balancing** (routes traffic evenly)
* **Configuration management** (injecting secrets/env vars)

Think of Kubernetes as a **traffic controller for containers**.

Instead of running Docker containers manually, Kubernetes manages **hundreds or thousands** of them across many servers.

---

## 🏗️ 2. Kubernetes Architecture (Simplified)

Kubernetes is divided into **two layers**:

| Layer             | Description                                                                                                 |
| ----------------- | ----------------------------------------------------------------------------------------------------------- |
| **Control Plane** | The “brain” — decides what should run and where. (API Server, Scheduler, Controller Manager, etcd)          |
| **Worker Nodes**  | The “muscle” — actually run your containers (pods) using Kubelet and container runtime (Docker/Containerd). |

Here’s how it looks visually:

```
+--------------------+         +----------------------+
| Control Plane (AWS)| <-----> | Worker Nodes (EC2s)  |
| - API Server       |         | - Kubelet            |
| - Scheduler        |         | - kube-proxy         |
| - Controller Mgr   |         | - Pods (containers)  |
| - etcd (state)     |         +----------------------+
+--------------------+
```

When you use **EKS**, AWS manages the **Control Plane**, and you manage the **Worker Nodes**.

---

## 🔹 3. Kubernetes Key Components

Let’s break down what each major component does — with examples.

---

### **1️⃣ Pod**

* The smallest deployable unit in Kubernetes.
* Encapsulates one or more containers that share resources (network, storage).

#### Example:

```bash
kubectl run myapp --image=nginx
kubectl get pods
```

**What happens:**

* A Pod called `myapp` is created.
* Inside, it runs the `nginx` container.

#### YAML equivalent:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
    - name: nginx
      image: nginx
      ports:
        - containerPort: 80
```

---

### **2️⃣ Deployment**

* Manages a set of Pods.
* Handles scaling, rolling updates, and rollback.

#### Example:

```bash
kubectl create deployment web --image=nginx
kubectl get deployments
```

#### YAML:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
```

This will run 3 Pods, each running NGINX, and Kubernetes ensures **always 3 are running**.

---

### **3️⃣ Service**

* Provides **stable networking** for Pods.
* Because Pods are dynamic (they restart, IPs change), Services give them a constant DNS name.

#### Example:

```bash
kubectl expose deployment web --port=80 --type=NodePort
kubectl get svc
```

This creates a **Service** that exposes your app outside the cluster.

#### YAML:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app: web
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: NodePort
```

---

### **4️⃣ ReplicaSet**

* Ensures a specific number of Pods are always running.
* Usually managed automatically by a Deployment.

Check:

```bash
kubectl get rs
```

If you scale a Deployment:

```bash
kubectl scale deployment web --replicas=5
```

→ ReplicaSet will adjust Pods accordingly.

---

### **5️⃣ Namespace**

* Logical isolation inside a cluster.
* You can run multiple projects or environments in the same cluster safely.

```bash
kubectl create namespace dev
kubectl get ns
kubectl run nginx --image=nginx -n dev
```

---

### **6️⃣ ConfigMap and Secret**

* **ConfigMap:** stores non-sensitive configuration (e.g., environment variables).
* **Secret:** stores sensitive data (passwords, keys, tokens).

#### Example:

```bash
kubectl create configmap app-config --from-literal=ENV=prod
kubectl create secret generic db-secret --from-literal=PASSWORD=admin123
kubectl get configmap,secret
```

#### Use inside a Pod:

```yaml
env:
  - name: ENV
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: ENV
  - name: DB_PASS
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: PASSWORD
```

---

### **7️⃣ Persistent Volume (PV) and Claim (PVC)**

Used for data that must survive Pod restarts.

#### Example PVC:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mypvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

Mount inside Pod:

```yaml
volumes:
  - name: data-storage
    persistentVolumeClaim:
      claimName: mypvc
```

---

## 🧠 4. How Kubernetes Works (Example Flow)

1. You run:

   ```bash
   kubectl apply -f deployment.yaml
   ```

2. The **API Server** stores your definition in **etcd**.

3. The **Scheduler** finds the best node to place the Pod on.

4. The **Kubelet** on that node:

   * Pulls the image
   * Starts the container
   * Reports status to API Server

5. The **Service** exposes it through a stable endpoint.

---

## 🧰 5. Kubernetes Tooling

| Tool        | Purpose                                          |
| ----------- | ------------------------------------------------ |
| **kubectl** | CLI to interact with the cluster                 |
| **kubeadm** | Tool to create clusters (used in local installs) |
| **eksctl**  | AWS tool to create EKS clusters                  |
| **Helm**    | Kubernetes package manager                       |
| **YAML**    | Declarative resource definition format           |

---

## 🧪 6. Mini Practice (Local or EKS-compatible)

If you have `kubectl` installed, try this mini hands-on:

```bash
# Run Nginx
kubectl create deployment nginx --image=nginx

# View all resources
kubectl get all

# Expose it
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Scale up
kubectl scale deployment nginx --replicas=5

# Check everything
kubectl get pods -o wide
```

---

✅ **End of Step 1 Summary**

You now understand:

* What Kubernetes is and how it works
* The role of Pods, Deployments, and Services
* The lifecycle and core components
* How to define workloads using YAML
* How Kubernetes automates management

---

# 🏗️ Step 2 — EKS Architecture (Detailed + Practical)

---

## 🚀 What Is EKS?

**Amazon Elastic Kubernetes Service (EKS)** is a **managed Kubernetes service** provided by AWS.
That means:

* AWS **manages the Kubernetes Control Plane** (the “brain”)
* You manage the **Worker Nodes**, networking, and workloads (the “muscle”)

EKS ensures:
✅ High availability (multi-AZ)
✅ Automatic control plane patching and upgrades
✅ IAM integration for Kubernetes RBAC
✅ AWS-native networking (Pods get VPC IPs)

---

## 🧠 1. EKS Architecture Overview

Let’s visualize it first:

```
                        ┌────────────────────────────┐
                        │ AWS Managed Control Plane  │
                        │  - API Server              │
                        │  - etcd                   │
                        │  - Scheduler              │
                        │  - Controller Manager      │
                        └────────────┬───────────────┘
                                     │
                          (Kubernetes API)
                                     │
           ┌─────────────────────────┴───────────────────────────┐
           │                                                     │
   ┌──────────────┐                                       ┌──────────────┐
   │ Node Group 1 │                                       │ Node Group 2 │
   │  EC2 nodes    │                                       │ Fargate pods  │
   │  (Linux)      │                                       │ (Serverless) │
   ├──────────────┤                                       ├──────────────┤
   │ Pods + CNI   │                                       │ Pods + CNI   │
   │ kubelet +     │                                      │ kubelet (AWS)│
   └──────────────┘                                       └──────────────┘
           │                                                     │
           └────────────── VPC (Subnets, SGs, Routes) ───────────┘
```

---

## 🧩 2. Core Components of EKS (With Explanations)

| Component                                  | Description                                                                                          |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| **Control Plane (Managed)**                | API Server, etcd, Scheduler, Controller Manager. Fully managed by AWS. You don’t see or SSH into it. |
| **Worker Nodes (Managed or Self-managed)** | EC2 instances (Linux/Windows) or AWS Fargate. They actually run your containers.                     |
| **Node Group**                             | A group of worker nodes managed together (with scaling, updates, etc.).                              |
| **VPC (Networking Layer)**                 | EKS must be deployed inside a VPC with public/private subnets and route tables.                      |
| **AWS CNI Plugin (`aws-node`)**            | Assigns VPC IPs directly to Pods. Pods are “first-class citizens” in your VPC.                       |
| **IAM Integration (`aws-auth` and IRSA)**  | Maps AWS IAM users/roles to Kubernetes RBAC for security and fine-grained access.                    |
| **Add-ons**                                | CoreDNS, kube-proxy, aws-node (networking), EBS/EFS CSI drivers for storage.                         |

---

## 🔸 3. How EKS Control Plane Works (AWS Side)

When you create an EKS cluster:

* AWS provisions **a managed control plane** in your chosen region.
* It automatically creates:

  * 3× API Server endpoints (multi-AZ)
  * Highly available `etcd` (for storing cluster state)
* AWS handles:

  * Control Plane upgrades
  * Patching
  * Automatic scaling

You can’t SSH or modify control plane nodes — they are AWS-managed.

You only interact with it via:

```bash
kubectl get nodes
kubectl get pods
```

and AWS APIs:

```bash
aws eks describe-cluster --name mycluster
```

---

## 🔸 4. How Worker Nodes Work (Your Side)

You create **Node Groups**, which are sets of EC2 instances registered to the control plane.

### Each node runs:

* `kubelet`: connects to Control Plane
* `kube-proxy`: handles network routing
* `aws-node` (CNI plugin): gives Pods VPC IPs

### You can have:

* **Managed Node Group** — AWS handles updates and lifecycle
* **Self-managed Node Group** — full control (but more admin work)
* **Fargate Profiles** — serverless Pods (no EC2 needed)

Example NodeGroup with `eksctl`:

```bash
eksctl create nodegroup \
  --cluster demo-cluster \
  --name ng1 \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed
```

---

## 🔸 5. Networking in EKS

EKS uses the **AWS VPC CNI Plugin**, which gives each Pod an IP address from your **VPC subnet**.

### Benefits:

✅ Native VPC routing — Pods can directly talk to AWS services
✅ Security groups and NACLs apply
✅ No NAT or overlay networks needed

### Drawbacks:

⚠️ Each EC2 instance has a limited number of IPs (ENI limits)
⚠️ Can exhaust subnet IPs for large clusters

### Important CNI Pods

```bash
kubectl get pods -n kube-system -l k8s-app=aws-node
```

These are the AWS CNI Pods that attach ENIs to nodes.

---

## 🔸 6. IAM Integration in EKS

### A. `aws-auth` ConfigMap (User ↔ RBAC Mapping)

This maps AWS IAM users/roles to Kubernetes roles.

To view:

```bash
kubectl -n kube-system get configmap aws-auth -o yaml
```

Example contents:

```yaml
apiVersion: v1
data:
  mapRoles: |
    - rolearn: arn:aws:iam::111122223333:role/EKS-NodeRole
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
  mapUsers: |
    - userarn: arn:aws:iam::111122223333:user/manoj
      username: manoj
      groups:
        - system:masters
```

This lets your IAM user (`manoj`) access the cluster as an admin.

---

### B. IRSA — IAM Role for Service Accounts

This lets **Pods** access AWS resources (like S3, DynamoDB) securely **without using instance roles**.

#### Steps:

1️⃣ Associate OIDC provider:

```bash
eksctl utils associate-iam-oidc-provider \
  --region us-east-1 \
  --cluster demo-cluster \
  --approve
```

2️⃣ Create a ServiceAccount with IAM permissions:

```bash
eksctl create iamserviceaccount \
  --name s3-access \
  --namespace default \
  --cluster demo-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --approve
```

3️⃣ Deploy a Pod using that service account:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: s3-test
spec:
  serviceAccountName: s3-access
  containers:
    - name: awscli
      image: amazonlinux
      command: ["sleep", "3600"]
```

Now, that Pod can directly read from S3 using AWS SDK without credentials.

---

## 🔸 7. EKS Storage

| Storage Type                  | Description                              | Best For                                  |
| ----------------------------- | ---------------------------------------- | ----------------------------------------- |
| **EBS (Elastic Block Store)** | Block-level storage attached to one node | Databases, single-writer apps             |
| **EFS (Elastic File System)** | Shared file storage (multi-node access)  | Multi-pod shared volumes                  |
| **FSx**                       | High-performance file systems            | Specialized workloads (Windows/Linux FSx) |
| **S3**                        | Object storage (via SDK/API)             | Backups, logs, static content             |

### Example: Dynamic EBS Provisioning

EKS supports **StorageClasses** for auto EBS volume creation:

```bash
kubectl get storageclass
```

Default: `gp2` or `gp3` managed by AWS EBS CSI driver.

PVC Example:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  storageClassName: gp3
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

---

## 🔸 8. EKS Add-ons

EKS automatically installs:

* **CoreDNS** – for cluster DNS resolution
* **kube-proxy** – for networking
* **aws-node** – VPC CNI plugin

You can manage these using the AWS CLI:

```bash
aws eks list-addons --cluster-name demo-cluster
aws eks update-addon --cluster-name demo-cluster --addon-name coredns
```

---

## 🔸 9. Observability & Monitoring

### A. Using CloudWatch Container Insights

```bash
eksctl utils associate-iam-oidc-provider --cluster demo-cluster --approve

# Install CW Agent + Fluent Bit
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/eks/latest/k8s-yaml-templates/fluent-bit/fluent-bit.yaml
```

### B. Using Prometheus & Grafana

Install via Helm:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack
```

---

## 🔸 10. Cost Optimization

| Strategy                       | Explanation                                  |
| ------------------------------ | -------------------------------------------- |
| **Use Spot Instances**         | Add spot node groups for stateless workloads |
| **Use Fargate for small jobs** | No EC2 cost when idle                        |
| **Scale down off-hours**       | Use Cluster Autoscaler or AWS EventBridge    |
| **Right-size instance types**  | Avoid over-provisioning nodes                |

---

## ✅ Summary of EKS Internals

| Layer         | Managed By               | Key Components              |
| ------------- | ------------------------ | --------------------------- |
| Control Plane | AWS                      | API Server, etcd, Scheduler |
| Worker Nodes  | You (or AWS for Fargate) | EC2, kubelet, aws-node      |
| Networking    | Shared                   | VPC, Subnets, CNI           |
| IAM           | Shared                   | aws-auth, IRSA              |
| Storage       | Shared                   | EBS, EFS, CSI Drivers       |
| Observability | You                      | CloudWatch, Prometheus      |

---

✅ **At the end of Step 2**, you should now understand:

* How EKS separates control plane and worker nodes
* How Pods get IPs via VPC CNI
* How IAM and RBAC work via `aws-auth` and IRSA
* What Add-ons, Storage, and Node Groups do
  
---

# 🧩 Step 3 — EKS Cluster Setup (Hands-On + Detailed)

---

## 🧠 What You’ll Learn Here

By the end of this step, you’ll:

* Create an **EKS cluster** using `eksctl`
* Set up **kubectl** for managing it
* Create and verify **node groups**
* Deploy a sample **application**
* Understand what happens behind the scenes

---

## 🔧 1. Prerequisites (Your System Setup)

Before you create a cluster, make sure you have:

| Tool                | Description                                                                                                                                                                             | Install Command                                                                                                                                                           |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **AWS CLI v2**      | Used to interact with AWS                                                                                                                                                               | `sudo apt install awscli` or [AWS CLI install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)                                       |
| **eksctl**          | Official CLI for EKS                                                                                                                                                                    | `curl -sLO https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz && tar -xzf eksctl_Linux_amd64.tar.gz && sudo mv eksctl /usr/local/bin` |
| **kubectl**         | Kubernetes CLI                                                                                                                                                                          | `curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.0/2024-08-12/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/`                  |
| **IAM permissions** | Your IAM user must have at least: `AmazonEKSClusterPolicy`, `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2FullAccess`, `IAMFullAccess`, and `CloudFormationFullAccess` |                                                                                                                                                                           |

Then confirm:

```bash
aws sts get-caller-identity
eksctl version
kubectl version --client
```

✅ You should see valid output for all.

---

## ☁️ 2. Step-by-Step EKS Cluster Creation

We’ll create a **demo EKS cluster** in **us-east-1** with **2 worker nodes**.

---

### 🧩 Step 1: Create the Cluster

```bash
eksctl create cluster \
  --name demo-cluster \
  --region us-east-1 \
  --version 1.30 \
  --nodegroup-name ng1 \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed
```

This command does the following automatically:

1. Creates a **VPC** (3 subnets across AZs)
2. Provisions the **EKS Control Plane**
3. Creates a **Managed Node Group** (2 EC2 instances)
4. Updates your `~/.kube/config` file for kubectl

This may take **10–15 minutes** the first time.

---

### 🧠 Behind the Scenes

Here’s what happens internally:

* **CloudFormation Stack** is created → contains VPC, IAM Roles, Security Groups, etc.
* **EKS API** creates the control plane (multi-AZ).
* Once ready, it launches **EC2 worker nodes** that join via bootstrap scripts.
* `aws-auth` ConfigMap is automatically updated to map node IAM roles.

---

### 🧩 Step 2: Verify Cluster Status

```bash
eksctl get cluster
```

Output:

```
NAME           REGION      EKSCTL CREATED
demo-cluster   us-east-1   True
```

Then check:

```bash
kubectl get nodes
```

Expected output:

```
NAME                                           STATUS   ROLES    AGE   VERSION
ip-192-168-xx-xx.ec2.internal                  Ready    <none>   3m    v1.30.x
ip-192-168-yy-yy.ec2.internal                  Ready    <none>   3m    v1.30.x
```

---

### 🧩 Step 3: Verify Core Components

These are default EKS add-ons:

```bash
kubectl get pods -n kube-system
```

You should see:

```
NAME                       READY   STATUS    RESTARTS   AGE
aws-node-xxxx               1/1     Running   0          5m
coredns-xxxx                1/1     Running   0          5m
kube-proxy-xxxx             1/1     Running   0          5m
```

✅ `aws-node` → AWS CNI plugin
✅ `coredns` → DNS resolution inside cluster
✅ `kube-proxy` → Networking for services

---

## 🧩 3. Accessing the Cluster (kubectl setup)

If you’re using a new terminal session later:

```bash
aws eks update-kubeconfig --region us-east-1 --name demo-cluster
```

Now test again:

```bash
kubectl get svc
```

---

## 🧩 4. Deploy a Sample Application

Let’s deploy a **simple NGINX web app**.

### Step 1 — Create a Deployment

```bash
kubectl create deployment web --image=nginx
```

### Step 2 — Expose the Deployment as a Service

```bash
kubectl expose deployment web --type=LoadBalancer --port=80
```

### Step 3 — Verify Deployment

```bash
kubectl get pods
kubectl get svc
```

Output:

```
NAME         TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)        AGE
web          LoadBalancer   10.100.200.1     a1b2c3d4.us-east-1.elb.amazonaws.com   80:30123/TCP   2m
```

🌐 Copy the **EXTERNAL-IP (ELB URL)** and open it in your browser.
You’ll see **NGINX Welcome Page** 🎉

---

## 🧩 5. Inspecting Your Resources

### List Nodes:

```bash
kubectl get nodes -o wide
```

### List Pods per Node:

```bash
kubectl get pods -o wide
```

### Describe Service:

```bash
kubectl describe svc web
```

### Clean up the Deployment:

```bash
kubectl delete svc web
kubectl delete deployment web
```

---

## 🧩 6. Scaling and Updating Nodes

### Scale Pods:

```bash
kubectl scale deployment web --replicas=4
```

### Scale Node Group:

```bash
eksctl scale nodegroup \
  --cluster demo-cluster \
  --name ng1 \
  --nodes 4
```

---

## 🧩 7. Cleaning Up the Cluster

When you’re done experimenting:

```bash
eksctl delete cluster --name demo-cluster --region us-east-1
```

This deletes:
✅ Control plane
✅ Node groups
✅ CloudFormation stacks
✅ VPC & networking resources

---

## 🧩 8. Troubleshooting Tips

| Issue                                | Fix                                              |
| ------------------------------------ | ------------------------------------------------ |
| `kubectl` gives error “unauthorized” | Re-run `aws eks update-kubeconfig`               |
| Nodes stuck in `NotReady`            | Check VPC subnet routes & security groups        |
| LoadBalancer not getting IP          | Ensure subnets are tagged for ELB auto-discovery |
| Add-ons missing                      | Check `kubectl get pods -n kube-system`          |
| Access denied (IAM)                  | Add user to `aws-auth` ConfigMap                 |

---

## 🧩 9. What You Just Built

✅ AWS-managed control plane
✅ Worker nodes in Auto Scaling group
✅ Fully networked VPC-based Kubernetes cluster
✅ Load-balanced web app via ALB

---

## 🔍 Optional: Custom VPC Cluster (Advanced)

If you want more control, you can pre-create your VPC:

```bash
eksctl create cluster \
  --name demo2 \
  --region us-east-1 \
  --vpc-private-subnets=subnet-xxxx,subnet-yyyy \
  --vpc-public-subnets=subnet-zzzz,subnet-aaaa
```

This is useful for production — gives control over IP ranges, routing, etc.

---

## ✅ Summary of Step 3

| Task                    | You Did                    |
| ----------------------- | -------------------------- |
| Installed tools         | awscli, eksctl, kubectl    |
| Created cluster         | Control Plane + Node Group |
| Verified cluster health | `kubectl get nodes/pods`   |
| Deployed sample app     | NGINX via LoadBalancer     |
| Scaled resources        | Pods + NodeGroups          |
| Cleaned up              | Deleted cluster            |

---

# 🌐 Step 4 — EKS Networking Deep Dive

---

## 🧠 Why Networking in EKS Is Different

In **standard Kubernetes**, Pods communicate via an **overlay network** (like Calico, Flannel, or WeaveNet).
But in **EKS**, AWS replaces that with the **VPC CNI plugin** — giving each Pod a **real VPC IP address**.

This means:
✅ Pods are first-class citizens in your AWS VPC
✅ They can communicate directly with other AWS resources
✅ Security Groups and NACLs apply to them
✅ No NAT or tunneling required

---

## 🧩 1. The Big Picture

```
                       ┌────────────────────────────────┐
                       │     AWS EKS Control Plane       │
                       └────────────────────────────────┘
                                      │
                                      │
                   ┌──────────────────┴──────────────────┐
                   │                                     │
          ┌─────────────────────┐              ┌─────────────────────┐
          │ Node 1 (EC2)        │              │ Node 2 (EC2)        │
          │ ────────────────    │              │ ────────────────    │
          │ eth0 → ENI → VPC    │              │ eth0 → ENI → VPC    │
          │                     │              │                     │
          │ Pod A (IP 10.0.1.10)│              │ Pod C (IP 10.0.2.15)│
          │ Pod B (IP 10.0.1.11)│              │ Pod D (IP 10.0.2.16)│
          └─────────────────────┘              └─────────────────────┘
```

Each Pod gets an IP directly from your VPC subnet.

---

## 🧩 2. AWS VPC CNI Plugin (aws-node)

This is the brain of EKS networking.
It runs as a **DaemonSet** on every node.

```bash
kubectl get ds aws-node -n kube-system
```

**What it does:**

* Allocates ENIs (Elastic Network Interfaces) to nodes
* Assigns VPC IPs from subnets to Pods
* Configures routes for Pod-to-Pod and Pod-to-Service communication

Each EC2 node has:

* 1 primary ENI (attached at launch)
* 1–3 secondary ENIs (depending on instance type)
* Each ENI supports multiple IPs

For example:

| Instance Type | Max ENIs | IPs per ENI | Total Pods Supported |
| ------------- | -------- | ----------- | -------------------- |
| t3.medium     | 3        | 6           | ~17                  |
| m5.large      | 3        | 10          | ~29                  |
| c5.xlarge     | 4        | 15          | ~54                  |

---

## 🧩 3. How Pods Communicate in EKS

### 📦 Pod-to-Pod (Same Node)

Traffic stays within the node — handled by **Linux bridge** or veth pairs.

### 📦 Pod-to-Pod (Different Nodes)

1. CNI assigns each Pod a VPC IP.
2. Each node adds a route for every Pod ENI.
3. Traffic goes **via VPC** → not overlay or NAT.
4. Security groups & NACLs apply directly.

✅ Faster, simpler, secure.

---

## 🧩 4. EKS Service Types (In Detail)

Kubernetes Services define **how your Pods are exposed** to the network.

### 🟢 A. ClusterIP (Default)

* Internal-only service inside the cluster.
* Pods can reach it via cluster DNS.
* No external access.

```bash
kubectl expose deployment web --type=ClusterIP --port=80
```

Test from another Pod:

```bash
kubectl run curl --image=radial/busyboxplus:curl -i --tty
curl http://web.default.svc.cluster.local
```

---

### 🟡 B. NodePort

* Exposes service on **each node’s IP** at a static port (e.g., 30080).
* Can be accessed via:
  `http://<NodePublicIP>:30080`

```bash
kubectl expose deployment web --type=NodePort --port=80 --target-port=80
kubectl get svc
```

---

### 🔵 C. LoadBalancer

* Integrates directly with **AWS ELB (Elastic Load Balancer)**.
* AWS automatically creates a Classic or NLB (Network Load Balancer).
* External access via `EXTERNAL-IP`.

```bash
kubectl expose deployment web --type=LoadBalancer --port=80
kubectl get svc
```

Output:

```
NAME   TYPE           CLUSTER-IP     EXTERNAL-IP                        PORT(S)
web    LoadBalancer   10.0.171.165   a1234b5678c9d.elb.amazonaws.com    80:30080/TCP
```

Visit the EXTERNAL-IP in browser → ✅ You’ll see NGINX welcome page.

---

### 🟣 D. Ingress (Layer 7)

* Smart routing based on **hostname or path**.
* Usually used with **AWS ALB Ingress Controller**.
* Routes traffic to multiple services via one ALB.

Example Ingress YAML:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  annotations:
    kubernetes.io/ingress.class: alb
spec:
  rules:
    - host: web.demo.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
```

---

## 🧩 5. AWS Load Balancer Controller

To use ALB/ELB natively, install the AWS Load Balancer Controller:

```bash
eksctl utils associate-iam-oidc-provider --cluster demo-cluster --approve

eksctl create iamserviceaccount \
  --cluster demo-cluster \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
  --approve
```

Then install the controller:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=demo-cluster
```

---

## 🧩 6. DNS Resolution (CoreDNS in EKS)

EKS includes **CoreDNS** to handle internal DNS lookups.

Pods can reach other services using:

```
<service>.<namespace>.svc.cluster.local
```

Example:

```
curl http://web.default.svc.cluster.local
```

To verify DNS:

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

If pods can’t resolve DNS — ensure CoreDNS is running and your node security group allows UDP/53.

---

## 🧩 7. Security Groups & Subnets

Each EKS node inherits its EC2 **security group**.
By default:

* Allows all outbound traffic.
* Allows inbound traffic from other nodes.

You can view node SGs:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:eks:nodegroup-name,Values=ng1" \
  --query "Reservations[].Instances[].SecurityGroups[].GroupId"
```

For LoadBalancers:

* Public subnets are tagged for external ELBs.
* Private subnets are tagged for internal ELBs.

Check:

```bash
aws ec2 describe-subnets --filters "Name=tag-key,Values=kubernetes.io/role/elb"
```

---

## 🧩 8. EKS Networking Cost Optimization

| Method                              | Description                                     | Benefit                 |
| ----------------------------------- | ----------------------------------------------- | ----------------------- |
| **Use Private Subnets**             | Keep nodes private and route LB traffic via NAT | Security + lower cost   |
| **Reduce Pod IP usage**             | Use secondary CIDRs or prefix delegation        | Avoid subnet exhaustion |
| **Cluster Autoscaler + CNI tuning** | Scale nodes efficiently                         | Save EC2 cost           |
| **NLB over CLB**                    | Use Network Load Balancer instead of Classic    | Lower latency + cheaper |

---

## 🧩 9. Debugging EKS Networking

| Problem                 | Command                                           | Meaning                     |
| ----------------------- | ------------------------------------------------- | --------------------------- |
| Pod can’t reach Service | `kubectl get endpoints <svc>`                     | Ensure endpoints exist      |
| Pod DNS fails           | `kubectl exec -it <pod> -- nslookup web`          | Check CoreDNS               |
| Pod IP missing          | `kubectl describe pod`                            | Check CNI logs              |
| Node IP exhausted       | `kubectl logs -n kube-system -l k8s-app=aws-node` | Check ENI allocation errors |

---

## ✅ Summary of Step 4

| Concept           | What You Learned                           |
| ----------------- | ------------------------------------------ |
| VPC CNI Plugin    | Pods get real VPC IPs (no overlay)         |
| Pod Communication | Pod ↔ Pod via VPC routing                  |
| Service Types     | ClusterIP, NodePort, LoadBalancer, Ingress |
| DNS               | CoreDNS manages internal resolution        |
| Load Balancers    | AWS ELB/NLB integrated via Service         |
| Troubleshooting   | CNI, ENI, and CoreDNS debugging            |

---

Now you have **end-to-end control** over how your EKS cluster communicates internally and externally.

---
