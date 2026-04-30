# Audit Answers — CRUD Master K8s Project

---

## SECTION 1 — General: Check the Repo Content

### Q: Are all the required files present?

**Answer: Yes. All required files are present.**

Run to verify:
```bash
ls -la
# Must show:
# README.md         ✅
# orchestrator.sh   ✅
# Vagrantfile       ✅
# Manifests/        ✅
# Scripts/          ✅
# Dockerfiles/      ✅
```

---

### Q: Does the project have the required structure?

**Answer: Yes. The required structure is present, plus an additional `srcs/` folder.**

```
.
├── Manifests/        ✅  All K8s YAML manifests
├── Scripts/          ✅  master.sh and agent.sh provisioning scripts
├── Dockerfiles/      ✅  All Dockerfiles for each service
├── Vagrantfile       ✅  Defines master + agent VMs
├── orchestrator.sh   ✅  Cluster lifecycle management script
├── README.md         ✅  Project documentation
└── srcs/             ℹ️  Additional folder — see justification below
```

**Justification for `srcs/` folder:**
> The `srcs/` directory was used during active development as an alternative iteration of the application code. The `Dockerfiles/` directory contains the final, production-ready versions that were used to build and push the Docker images currently running in the cluster. The `srcs/` folder was retained for reference and development history but does not affect the deployed infrastructure.

---

## SECTION 2 — Conceptual Questions

### Q: What is container orchestration, and what are its benefits?

**Answer:**

Container orchestration is the automated management of containerized applications across multiple hosts — covering deployment, scaling, networking, load balancing, and self-healing.

**Benefits:**
- **Automated deployment** — deploy containers without manual intervention
- **Auto-scaling** — scale up or down based on load (CPU, memory)
- **Self-healing** — automatically restart failed containers
- **Load balancing** — distribute traffic evenly across replicas
- **Service discovery** — containers find each other by name, not IP
- **Rolling updates** — update apps with zero downtime
- **Resource efficiency** — pack workloads optimally across nodes

---

### Q: What is Kubernetes, and what is its main role?

**Answer:**

Kubernetes (K8s) is an open-source container orchestration platform originally developed by Google. Its main role is to **automate the deployment, scaling, and management of containerized applications** across a cluster of machines.

It works by letting you declare the *desired state* (e.g., "I want 3 replicas of this app") and continuously reconciling the actual state of the cluster to match it. Key capabilities include:
- Managing Pods, Deployments, StatefulSets
- Networking via Services
- Storing config and secrets
- Auto-scaling via HPA
- Persistent storage via PersistentVolumeClaims

---

### Q: What is K3s, and what is its main role?

**Answer:**

K3s is a **lightweight, certified Kubernetes distribution** created by Rancher Labs. It packages the full Kubernetes API into a single binary under 100MB and uses significantly fewer resources (~512MB RAM vs ~4GB for full K8s).

**Main role:** Run a fully functional Kubernetes cluster on resource-constrained environments such as virtual machines, edge devices, Raspberry Pi, or CI pipelines — which is exactly why it's used here with Vagrant VMs.

**What K3s removes vs full K8s:**
- No cloud-provider integrations
- No legacy/alpha APIs
- Uses SQLite instead of etcd by default
- Uses Traefik as the default ingress controller

---

## SECTION 3 — Check Student Documentation

### Q: Does the README.md contain all required information?

**Answer: Yes.**

Open the README.md to show the auditor:
```bash
cat README.md
```

The README covers:
- **Prerequisites** — Vagrant, VirtualBox, kubectl, Docker
- **Configuration** — environment variables, secrets explanation
- **Setup** — `./orchestrator.sh create`
- **Usage** — all API endpoints with example requests

---

## SECTION 4 — Check Docker Hub Images

### Q: Are the Docker images uploaded from the student's Docker Hub account?

**Answer: Yes. All 6 images are on Docker Hub under `hussainsaddam/`.**

Verify by pulling them:
```bash
docker pull hussainsaddam/api-gateway:1.0
docker pull hussainsaddam/inventory-app:1.0
docker pull hussainsaddam/inventory-database:1.0
docker pull hussainsaddam/billing-app:1.0
docker pull hussainsaddam/billing-database:1.0
docker pull hussainsaddam/rabbitmq:1.0
```

Images referenced in manifests:
| Service | Docker Hub Image |
|---|---|
| API Gateway | `hussainsaddam/api-gateway:1.0` |
| Inventory App | `hussainsaddam/inventory-app:1.0` |
| Inventory Database | `hussainsaddam/inventory-database:1.0` |
| Billing App | `hussainsaddam/billing-app:1.0` |
| Billing Database | `hussainsaddam/billing-database:1.0` |
| RabbitMQ | `hussainsaddam/rabbitmq:1.0` |

---

## SECTION 5 — Check the Cluster

### Q: Is kubectl installed and configured?

```bash
kubectl version --client
kubectl cluster-info
```

---

### Q: Was the cluster created by a Vagrantfile?

**Answer: Yes.**

```bash
cat Vagrantfile
# Shows: master VM (192.168.56.10) and agent VM (192.168.56.11)
# Each provisioned with Scripts/master.sh and Scripts/agent.sh
```

---

### Q: Does the cluster contain two nodes — master and agent? Are they Ready?

```bash
kubectl get nodes -A
```

**Expected output:**
```
NAME     STATUS   ROLES           AGE   VERSION
master   Ready    control-plane   Xh    v1.35.4+k3s1
agent    Ready    <none>          Xh    v1.35.4+k3s1
```

---

## SECTION 6 — Check Student Infrastructure

### Q: Does the orchestrator.sh script create and manage the infrastructure?

**Answer: Yes. It supports: `create`, `start`, `stop`, `status`, `logs`.**

```bash
# Show the script commands
./orchestrator.sh
# Output shows: create | start | stop | status | logs
```

To create from scratch:
```bash
./orchestrator.sh create
# Output: "cluster created"
```

---

### Q: Did the student respect the architecture? Did infrastructure start correctly?

```bash
kubectl get all
```

**Architecture compliance:**
| Service | Kind | Reason |
|---|---|---|
| api-gateway-app | Deployment | Stateless, needs HPA scaling |
| inventory-app | Deployment | Stateless, needs HPA scaling |
| rabbitmq | Deployment | Stateless message broker |
| billing-app | StatefulSet | Needs stable identity for queue processing |
| billing-database | StatefulSet | Needs persistent storage + stable identity |
| inventory-database | StatefulSet | Needs persistent storage + stable identity |

---

## SECTION 7 — Verify K8s Manifests

### Q: Is there a YAML manifest for each service?

**Answer: Yes — 8 manifests total:**

```bash
ls Manifests/
```

| File | Resource |
|---|---|
| `api-gateway-deployment.yaml` | Deployment + Service for API Gateway |
| `inventory-app-deployment.yaml` | Deployment + Service for Inventory App |
| `inventory-db-statefulset.yaml` | StatefulSet + Service for Inventory DB |
| `billing-app-statefulset.yaml` | StatefulSet + Service for Billing App |
| `billing-db-statefulset.yaml` | StatefulSet + Service for Billing DB |
| `rabbitmq-deployment.yaml` | Deployment + Service for RabbitMQ |
| `hpa.yaml` | HPA for api-gateway and inventory-app |
| `secrets.yaml` | All credentials as K8s Secrets |

---

### Q: Are credentials absent from all manifests except secrets.yaml?

**Answer: Yes. All manifests use `secretKeyRef` — no hardcoded values.**

Example from any deployment YAML:
```yaml
env:
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:           # ← references the secret, never hardcodes
      name: billing-db-secret
      key: POSTGRES_PASSWORD
```

Only `secrets.yaml` contains credential values, and they are base64 encoded:
```bash
cat Manifests/secrets.yaml
# Shows: POSTGRES_PASSWORD: YmlsbGluZ19wYXNz  (base64, not plaintext)
```

---

## SECTION 8 — IaC and Manifest Questions

### Q: What is Infrastructure as Code and what are its advantages?

**Answer:**

Infrastructure as Code (IaC) means defining and managing infrastructure (servers, networks, services) through **machine-readable configuration files** instead of manual processes.

**Advantages:**
- **Reproducibility** — same config always produces identical infrastructure
- **Version control** — infrastructure changes tracked in Git like application code
- **Automation** — deploy entire stack with one command (`./orchestrator.sh create`)
- **Auditability** — full history of who changed what and when
- **Consistency** — eliminates "works on my machine" problems
- **Speed** — provision environments in minutes, not hours
- **Disaster recovery** — recreate entire infrastructure from code if something breaks

---

### Q: Explain what a K8s manifest is.

**Answer:**

A K8s manifest is a **YAML file that declares the desired state** of a Kubernetes resource. You describe *what you want* — Kubernetes figures out *how to achieve it* and continuously reconciles the actual cluster state to match the manifest.

Every manifest has 4 required fields:
```yaml
apiVersion: apps/v1      # API group and version
kind: Deployment         # Resource type
metadata:
  name: my-app           # Resource name
spec:                    # Desired state definition
  replicas: 2
  ...
```

---

### Q: Explain each K8s manifest in the project.

**`api-gateway-deployment.yaml`**
> Deploys the API Gateway as a Deployment (stateless). Exposes port 3000 via NodePort 30000 so external traffic reaches it. Injects `INVENTORY_SERVICE_URL`, `BILLING_SERVICE_URL`, and RabbitMQ credentials from secrets. Has liveness (`/health`) and readiness (`/ready`) probes.

**`inventory-app-deployment.yaml`**
> Deploys Inventory App as a Deployment (stateless). ClusterIP service on port 8080. Injects DB connection details from `inventory-db-secret`. Has liveness and readiness probes.

**`inventory-db-statefulset.yaml`**
> Deploys inventory PostgreSQL as a StatefulSet with a PersistentVolumeClaim for data durability. Headless ClusterIP service on port 5432. Injects credentials from `inventory-db-secret`.

**`billing-app-statefulset.yaml`**
> Deploys Billing App as a StatefulSet (not Deployment) because it needs stable identity for RabbitMQ queue consumption — only one consumer processes each message. Injects DB and RabbitMQ credentials from secrets.

**`billing-db-statefulset.yaml`**
> Deploys billing PostgreSQL as a StatefulSet with a PersistentVolumeClaim. Headless ClusterIP service on port 5432. Injects credentials from `billing-db-secret`. Creates the `orders` database.

**`rabbitmq-deployment.yaml`**
> Deploys RabbitMQ as a Deployment. Exposes AMQP port 5672 and management UI port 15672. Injects credentials from `rabbitmq-secret`.

**`hpa.yaml`**
> Defines two HorizontalPodAutoscalers — one for api-gateway and one for inventory-app. Both scale between 1 and 3 replicas when CPU exceeds 60%.

**`secrets.yaml`**
> Stores all credentials as base64-encoded K8s Secrets: `inventory-db-secret`, `billing-db-secret`, `rabbitmq-secret`. Referenced by all other manifests via `secretKeyRef`.

---

## SECTION 9 — Check Secrets

### Q: Are all credentials present in secrets?

```bash
kubectl get secrets -o json
```

Or cleaner:
```bash
kubectl get secrets
# Shows: billing-db-secret, inventory-db-secret, rabbitmq-secret

kubectl describe secret billing-db-secret
kubectl describe secret inventory-db-secret
kubectl describe secret rabbitmq-secret
```

**Secrets present:**
| Secret | Keys |
|---|---|
| `inventory-db-secret` | POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD |
| `billing-db-secret` | POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD |
| `rabbitmq-secret` | RABBITMQ_DEFAULT_USER, RABBITMQ_DEFAULT_PASS, RABBITMQ_HOST, RABBITMQ_PORT, RABBITMQ_QUEUE |

---

## SECTION 10 — Check All Deployed Resources

### Q: Are all required applications deployed on correct ports?

```bash
kubectl get all
```

**Full resource list:**
```bash
kubectl get pods -o wide
# All 6 pods 1/1 Running

kubectl get svc
# api-gateway-app   NodePort   3000:30000/TCP
# billing-app       ClusterIP  8080/TCP
# billing-database  ClusterIP  5432/TCP
# inventory-app     ClusterIP  8080/TCP
# inventory-database ClusterIP 5432/TCP
# rabbitmq          ClusterIP  5672/TCP,15672/TCP
```

---

### Q: Do all apps deploy with correct configuration (StatefulSet, Deployment, HPA)?

```bash
# Verify deployments
kubectl get deployments
# api-gateway-app  1/1
# inventory-app    1/1
# rabbitmq         1/1

# Verify statefulsets
kubectl get statefulsets
# billing-app         1/1
# billing-database    1/1
# inventory-database  1/1

# Verify HPA
kubectl get hpa
# api-gateway-hpa    cpu: 2%/60%   min:1  max:3
# inventory-app-hpa  cpu: 2%/60%   min:1  max:3

# Verify persistent volumes
kubectl get pvc
# Shows PVCs for billing-database and inventory-database
```

---

## SECTION 11 — StatefulSet, Deployment, Scaling Questions

### Q: What is a StatefulSet in K8s?

**Answer:**

A StatefulSet manages pods that require **stable, persistent identity**. Each pod gets:
- A fixed, ordered name (`pod-0`, `pod-1`, `pod-2`)
- Its own dedicated PersistentVolume that follows it if rescheduled
- Ordered, graceful deployment and scaling (one at a time)

Used in this project for: `billing-app`, `billing-database`, `inventory-database`.

---

### Q: What is a Deployment in K8s?

**Answer:**

A Deployment manages **stateless, interchangeable pods**. Pods can be killed and recreated anywhere on any node — they are identical and hold no unique state. Features:
- Desired replica count maintained automatically
- Rolling updates and rollbacks
- Works with HPA for auto-scaling

Used in this project for: `api-gateway-app`, `inventory-app`, `rabbitmq`.

---

### Q: What is the difference between Deployment and StatefulSet?

| Feature | Deployment | StatefulSet |
|---|---|---|
| Pod identity | Random names (`pod-abc123`) | Stable ordered names (`pod-0`) |
| Storage | Shared or none | Each pod gets its own PVC |
| Startup order | All pods start simultaneously | Ordered (0, then 1, then 2) |
| Use case | Stateless apps | Databases, queues, stateful apps |
| Scaling | Any pod removed randomly | Pods removed in reverse order |

---

### Q: What is scaling and why do we use it?

**Answer:**

Scaling means **adjusting the number of running pod replicas** to match demand.

- **Horizontal scaling (HPA)** — add more pod replicas when CPU/memory is high, remove them when load drops
- **Why we use it** — ensures the application can handle traffic spikes without over-provisioning resources during quiet periods

In this project:
```bash
kubectl get hpa
# api-gateway and inventory-app scale 1→3 replicas when CPU > 60%
```

---

### Q: What is a load balancer and what is its role?

**Answer:**

A load balancer **distributes incoming network traffic across multiple pod replicas** so no single pod is overwhelmed.

In Kubernetes, the **Service** resource acts as an internal load balancer — when HPA scales api-gateway to 3 replicas, the Service automatically distributes requests across all 3 pods using round-robin. Externally, the NodePort service on port 30000 acts as the entry point.

---

### Q: Why don't we put the database as a Deployment?

**Answer:**

Databases need three things Deployments cannot guarantee:

1. **Stable storage** — each DB pod must always connect to the same data volume. Deployments share or reassign volumes randomly.
2. **Stable network identity** — apps connect to `billing-database-0` by name. Deployment pods get random names that change on restart.
3. **Ordered startup/shutdown** — replicated databases must start primary before replicas to avoid data corruption. Deployments start all pods simultaneously.

If a database were a Deployment, restarting a pod could attach it to a different (or empty) volume — **data would be lost**.

---

## SECTION 12 — Test the Solution

### Gateway IP and Port

```
GATEWAY IP:   192.168.56.10
GATEWAY PORT: 30000
Full URL:     http://192.168.56.10:30000
```

---

### Inventory API — POST a movie

**Postman:** POST `http://192.168.56.10:30000/api/movies/`
**Body (JSON):**
```json
{
  "title": "A new movie",
  "description": "Very short description"
}
```

Or via terminal:
```bash
curl -s -X POST http://192.168.56.10:30000/api/movies/ \
  -H "Content-Type: application/json" \
  -d '{"title": "A new movie", "description": "Very short description"}' \
  | python3 -m json.tool
```

**Expected:** HTTP 200, `"success": true`, movie object in response.

---

### Inventory API — GET all movies

**Postman:** GET `http://192.168.56.10:30000/api/movies/`

Or via terminal:
```bash
curl -s http://192.168.56.10:30000/api/movies/ | python3 -m json.tool
```

**Expected:** HTTP 200, JSON with `"movies": [...]` array containing the added movie.

---

### Billing API — POST an order (user_id=20)

**Postman:** POST `http://192.168.56.10:30000/api/billing/`
**Body (JSON):**
```json
{
  "user_id": "20",
  "number_of_items": "99",
  "total_amount": "250"
}
```

Or via terminal:
```bash
curl -s -X POST http://192.168.56.10:30000/api/billing/ \
  -H "Content-Type: application/json" \
  -d '{"user_id": "20", "number_of_items": "99", "total_amount": "250"}' \
  | python3 -m json.tool
```

**Expected:** HTTP 200, `"message": "Order accepted and queued for processing"`.

---

### Stop the billing-app container

```bash
kubectl scale statefulset billing-app --replicas=0
```

Confirm it stopped:
```bash
kubectl get pods | grep billing-app
# Should show nothing (no billing-app-0 pod)
```

---

### Billing API — POST while billing-app is stopped (user_id=22)

```bash
curl -s -X POST http://192.168.56.10:30000/api/billing/ \
  -H "Content-Type: application/json" \
  -d '{"user_id": "22", "number_of_items": "10", "total_amount": "50"}' \
  | python3 -m json.tool
```

**Expected:** HTTP 200 even though billing-app is down.
**Why it works:** The gateway publishes to RabbitMQ durable queue immediately and returns 200. The billing-app is not involved in this response.

---

### PostgreSQL Billing Database — Check orders

**Note:** The audit says `sudo -i -u postgres` but this container does not have `sudo`. Use the direct psql command instead:

```bash
# List databases — confirm "orders" is present
kubectl exec -it billing-database-0 -- \
  /usr/lib/postgresql/13/bin/psql -h localhost -U billing_user -d orders -c "\l"

# Check orders table — user_id=20 present, user_id=22 NOT present yet
kubectl exec -it billing-database-0 -- \
  /usr/lib/postgresql/13/bin/psql -h localhost -U billing_user -d orders -c "TABLE orders;"
```

**Expected:** `orders` database listed, user_id=20 row present, user_id=22 row absent.

---

### Resilience — Restart billing-app and confirm user_id=22 appears

```bash
# Start billing-app back
kubectl scale statefulset billing-app --replicas=1

# Confirm it's running
kubectl get pods | grep billing-app
# billing-app-0   1/1   Running

# Watch logs to see it consume the queued message
kubectl logs billing-app-0
# Look for: "Order committed to PostgreSQL database"

# Verify user_id=22 now in DB
kubectl exec -it billing-database-0 -- \
  /usr/lib/postgresql/13/bin/psql -h localhost -U billing_user -d orders -c "TABLE orders;"
```

**Expected:** Both user_id=20 and user_id=22 now present in the orders table.

---

## SECTION 13 — K8s Components (15-minute explanation)

| Component | Layer | Role |
|---|---|---|
| **Pod** | Workload | Smallest deployable unit — wraps one or more containers that share network and storage |
| **Node** | Infrastructure | Physical or virtual machine that runs pods; can be master (control plane) or worker (agent) |
| **Deployment** | Workload | Manages stateless pod replicas; handles rolling updates, rollbacks, and desired replica count |
| **StatefulSet** | Workload | Manages stateful pods with stable names, stable storage, and ordered startup/shutdown |
| **Service** | Networking | Stable network endpoint that load-balances traffic across pod replicas; types: ClusterIP, NodePort, LoadBalancer |
| **ConfigMap** | Config | Stores non-sensitive configuration data as key-value pairs; injected into pods as env vars or files |
| **Secret** | Config | Stores sensitive data (passwords, tokens) as base64-encoded values; injected via `secretKeyRef` |
| **HPA** | Scaling | HorizontalPodAutoscaler — automatically adjusts replica count based on CPU or memory metrics |
| **PersistentVolumeClaim (PVC)** | Storage | Request for durable storage; binds to a PersistentVolume so data survives pod restarts |
| **PersistentVolume (PV)** | Storage | Actual storage resource in the cluster (disk, NFS, cloud volume) provisioned for pods |
| **Namespace** | Organization | Logical isolation boundary within a cluster — separates workloads, teams, or environments |
| **ReplicaSet** | Workload | Ensures a specified number of pod replicas are running; managed automatically by Deployments |
| **Ingress** | Networking | HTTP/HTTPS routing rules — routes external traffic to Services based on host/path |
| **kube-apiserver** | Control Plane | The front door of the cluster — all kubectl commands and internal communication go through it |
| **etcd** | Control Plane | Distributed key-value store that holds the entire cluster state; single source of truth |
| **kube-scheduler** | Control Plane | Watches for new pods and assigns them to the best available node based on resources |
| **kube-controller-manager** | Control Plane | Runs controllers that reconcile desired state (ReplicaSet controller, Node controller, etc.) |
| **kubelet** | Node Agent | Agent running on every node — ensures containers described in PodSpecs are running and healthy |
| **kube-proxy** | Node Agent | Manages network routing rules on each node to implement Service load balancing |
| **Container Runtime** | Node | Software that runs containers (containerd, CRI-O) — K3s uses containerd by default |

