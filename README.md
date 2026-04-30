# CRUD Master — K3s Kubernetes Microservices

A production-grade Kubernetes (K3s) cluster deploying six microservices across a two-node distributed system. This project demonstrates containerization, infrastructure-as-code, Kubernetes orchestration, auto-scaling, and message-driven resilience.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Services](#services)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Setup & Deployment](#setup--deployment)
- [Usage & API Reference](#usage--api-reference)
- [Cluster Management](#cluster-management)
- [Database Access](#database-access)
- [Troubleshooting](#troubleshooting)
- [Security](#security)

---

## Overview

This project migrates a microservices architecture from a Docker Compose setup to a production-ready **K3s Kubernetes cluster** running on 2 Vagrant VMs (1 master, 1 agent). The six services communicate through HTTP APIs and a RabbitMQ message queue, with full auto-scaling and persistent storage.

**Key features:**
- Two-node K3s cluster provisioned entirely by Vagrantfile
- All infrastructure managed with a single `orchestrator.sh` script
- Stateless services auto-scale via HPA (1–3 replicas, 60% CPU trigger)
- Stateful services (databases, billing-app) use PersistentVolumeClaims for data durability
- RabbitMQ ensures billing orders are never lost even when billing-app is offline
- All credentials stored exclusively in Kubernetes Secrets — never hardcoded

---

## Architecture

```
                        ┌──────────────────────────────────────────────┐
  External Traffic      │         Kubernetes Cluster (K3s)             │
  http://               │                                              │
  192.168.56.10:30000   │  ┌─────────────────────────────────────┐    │
        │               │  │   Master Node — 192.168.56.10        │    │
        ▼               │  │   K3s Server · API Server            │    │
  ┌─────────────┐       │  │   Scheduler · Controller Manager     │    │
  │ api-gateway │       │  │   etcd · kube-proxy                  │    │
  │ (NodePort   │       │  │                                      │    │
  │  :30000)    │       │  │   Pods: api-gateway · billing-app    │    │
  └──────┬──────┘       │  │          rabbitmq                    │    │
         │              │  └─────────────────────────────────────┘    │
    ┌────┴─────┐         │                                              │
    ▼          ▼         │  ┌─────────────────────────────────────┐    │
┌───────┐ ┌────────┐     │  │   Agent Node — 192.168.56.11         │    │
│ /api/ │ │ /api/  │     │  │   K3s Agent · kube-proxy             │    │
│movies │ │billing │     │  │                                      │    │
└───┬───┘ └───┬────┘     │  │   Pods: inventory-app                │    │
    │         │          │  │          inventory-database          │    │
    ▼         ▼          │  │          billing-database            │    │
┌────────┐ ┌────────┐    │  └─────────────────────────────────────┘    │
│Inventory│ │RabbitMQ│    │                                              │
│  App   │ │ Queue  │    │   PersistentVolumes for both databases       │
└───┬────┘ └───┬────┘    │   Kubernetes Secrets for all credentials     │
    │          │         │   HPA auto-scaling for gateway + inventory   │
    ▼          ▼         └──────────────────────────────────────────────┘
┌────────┐ ┌────────┐
│Inventory│ │Billing │
│   DB   │ │  App   │
│(movies)│ └───┬────┘
└────────┘     ▼
           ┌────────┐
           │Billing │
           │   DB   │
           │(orders)│
           └────────┘
```

---

## Services

| Service | Kind | Replicas | Port | Purpose |
|---|---|---|---|---|
| `api-gateway-app` | Deployment + HPA | 1–3 | 3000 (NodePort 30000) | Single entry point — routes all external requests |
| `inventory-app` | Deployment + HPA | 1–3 | 8080 | Inventory CRUD API (movies database) |
| `billing-app` | StatefulSet | 1 | 8080 | Billing consumer — processes orders from RabbitMQ queue |
| `rabbitmq` | Deployment | 1 | 5672 / 15672 | Message broker — decouples gateway from billing-app |
| `inventory-database` | StatefulSet | 1 | 5432 | PostgreSQL — stores movies (`movies` database) |
| `billing-database` | StatefulSet | 1 | 5432 | PostgreSQL — stores orders (`orders` database) |

---

## Prerequisites

### System Requirements

| Requirement | Minimum |
|---|---|
| RAM | 4 GB free (2 GB per VM) |
| Disk | 20 GB free |
| CPU | 2 cores with virtualization support (VT-x / AMD-V) |
| OS | macOS, Linux, or Windows |

### Required Software

**1. VirtualBox 7.0+**
```bash
# macOS
brew install virtualbox

# Ubuntu/Debian
sudo apt install virtualbox
```

**2. Vagrant 2.4+**
```bash
# macOS
brew install vagrant

# Ubuntu/Debian
sudo apt install vagrant
```

**3. kubectl**
```bash
# macOS
brew install kubectl

# Ubuntu/Debian
sudo apt-get install -y kubectl
```

**4. Docker** *(only needed to rebuild images)*
```bash
# macOS
brew install docker
```

---

## Project Structure

```
orchestrator/
│
├── Vagrantfile                        # Defines master (192.168.56.10) + agent (192.168.56.11) VMs
├── orchestrator.sh                    # Cluster lifecycle: create | start | stop | status | logs
├── README.md                          # This file
│
├── Scripts/
│   ├── master.sh                      # Provisions K3s server on master VM
│   ├── agent.sh                       # Provisions K3s agent on worker VM
│   └── k3s-node-token                 # Shared token for agent to join cluster
│
├── Manifests/                         # All Kubernetes YAML definitions
│   ├── secrets.yaml                   # All credentials (base64 encoded)
│   ├── inventory-db-statefulset.yaml  # PostgreSQL for inventory
│   ├── billing-db-statefulset.yaml    # PostgreSQL for billing
│   ├── rabbitmq-deployment.yaml       # RabbitMQ message broker
│   ├── inventory-app-deployment.yaml  # Inventory REST API
│   ├── billing-app-statefulset.yaml   # Billing queue consumer
│   ├── api-gateway-deployment.yaml    # API Gateway (external entry point)
│   └── hpa.yaml                       # Auto-scaling rules for gateway + inventory
│
├── Dockerfiles/                       # Dockerfiles + source code for all services
│   ├── api-gateway/
│   │   ├── app/                       # Application source code
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── server.py
│   ├── billing-app/
│   │   ├── app/
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── server.py
│   ├── billing-database/
│   │   ├── Dockerfile
│   │   └── entrypoint.sh              # DB init + startup script
│   ├── inventory-app/
│   │   ├── app/
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── server.py
│   ├── inventory-database/
│   │   ├── Dockerfile
│   │   └── entrypoint.sh              # DB init + startup script
│   └── rabbitmq/
│       ├── Dockerfile
│       └── entrypoint.sh              # RabbitMQ startup script
│
└── docker-compose.yml                 # Legacy reference (not used in K8s deployment)
```

---

## Configuration

### Kubernetes Secrets

All credentials are stored in `Manifests/secrets.yaml` as Kubernetes Secret objects with base64-encoded values. **No plaintext credentials exist anywhere in the manifests.**

| Secret Name | Keys |
|---|---|
| `inventory-db-secret` | `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` |
| `billing-db-secret` | `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` |
| `rabbitmq-secret` | `RABBITMQ_DEFAULT_USER`, `RABBITMQ_DEFAULT_PASS`, `RABBITMQ_HOST`, `RABBITMQ_PORT`, `RABBITMQ_QUEUE` |

To encode a new value:
```bash
echo -n "mypassword" | base64
# bXlwYXNzd29yZA==
```

To decode an existing secret:
```bash
kubectl get secret billing-db-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
```

### Docker Hub Images

All images are published to Docker Hub under `hussainsaddam/`:

| Image | Tag |
|---|---|
| `hussainsaddam/api-gateway` | `1.0` |
| `hussainsaddam/inventory-app` | `1.0` |
| `hussainsaddam/billing-app` | `1.0` |
| `hussainsaddam/inventory-database` | `1.0` |
| `hussainsaddam/billing-database` | `1.0` |
| `hussainsaddam/rabbitmq` | `1.0` |

> All images must be **public** on Docker Hub for the cluster to pull them without authentication.

---

## Setup & Deployment

### Step 1 — Create the Cluster

```bash
./orchestrator.sh create
```

This single command:
1. Launches 2 Debian 11 VMs via Vagrant (master + agent)
2. Installs K3s server on master, K3s agent on worker
3. Copies kubeconfig to `~/.kube/config` on your local machine
4. Applies all Kubernetes manifests in dependency order
5. Prints `cluster created` when complete

**Expected output:**
```
NAME     STATUS   ROLES           AGE   VERSION
master   Ready    control-plane   30s   v1.35.4+k3s1
agent    Ready    <none>          20s   v1.35.4+k3s1

cluster created
```

### Step 2 — Verify All Pods Are Running

```bash
kubectl get pods -o wide
```

**Expected (all 6 pods `1/1 Running`):**
```
NAME                               READY   STATUS    NODE
api-gateway-app-XXXXX              1/1     Running   master
billing-app-0                      1/1     Running   master
billing-database-0                 1/1     Running   agent
inventory-app-XXXXX                1/1     Running   agent
inventory-database-0               1/1     Running   agent
rabbitmq-XXXXX                     1/1     Running   master
```

### Step 3 — Verify Full Infrastructure

```bash
kubectl get all          # All resources overview
kubectl get svc          # Services and ports
kubectl get hpa          # HPA status and CPU targets
kubectl get secrets      # Credentials
kubectl get pvc          # Persistent volumes for databases
```

---

## Usage & API Reference

**Gateway base URL:** `http://192.168.56.10:30000`

### Inventory Endpoints

#### Create a Movie
```bash
curl -s -X POST http://192.168.56.10:30000/api/movies/ \
  -H "Content-Type: application/json" \
  -d '{"title": "A new movie", "description": "Very short description"}' \
  | python3 -m json.tool
```

#### Get All Movies
```bash
curl -s http://192.168.56.10:30000/api/movies/ | python3 -m json.tool
```

#### Get Movie by ID
```bash
curl -s http://192.168.56.10:30000/api/movies/1 | python3 -m json.tool
```

#### Update a Movie
```bash
curl -s -X PUT http://192.168.56.10:30000/api/movies/1 \
  -H "Content-Type: application/json" \
  -d '{"title": "Updated title"}' \
  | python3 -m json.tool
```

#### Delete a Movie
```bash
curl -s -X DELETE http://192.168.56.10:30000/api/movies/1
```

### Billing Endpoint

#### Create a Billing Order
```bash
curl -s -X POST http://192.168.56.10:30000/api/billing/ \
  -H "Content-Type: application/json" \
  -d '{"user_id": "20", "number_of_items": "99", "total_amount": "250"}' \
  | python3 -m json.tool
```

> **Resilience:** The gateway returns `200 OK` immediately by publishing the order to RabbitMQ. The billing-app processes it asynchronously. If billing-app is offline, the message waits in the durable queue and is processed when the service restarts — **no orders are ever lost**.

### Health Check
```bash
curl http://192.168.56.10:30000/health
curl http://192.168.56.10:30000/ready
```

---

## Cluster Management

### Available Commands

```bash
./orchestrator.sh create   # Create VMs + deploy full cluster from scratch
./orchestrator.sh start    # Resume suspended VMs + redeploy manifests
./orchestrator.sh stop     # Delete resources + suspend VMs
./orchestrator.sh status   # Show nodes, pods, and services
./orchestrator.sh logs <pod-name>  # Stream logs for a specific pod
```

### Scaling

HPA auto-scales api-gateway and inventory-app based on CPU:

```bash
# View current HPA state
kubectl get hpa

# Manual scale override (temporary)
kubectl scale deployment api-gateway-app --replicas=3

# Describe HPA events
kubectl describe hpa api-gateway-app-hpa
```

### Stop and Restart Billing App (Resilience Demo)

```bash
# Stop billing-app
kubectl scale statefulset billing-app --replicas=0

# Start it back
kubectl scale statefulset billing-app --replicas=1

# Watch it recover and consume queued messages
kubectl logs -f billing-app-0
```

### SSH Into Nodes

```bash
vagrant ssh master
vagrant ssh agent
```

---

## Database Access

### Inventory Database (movies)

```bash
kubectl exec -it inventory-database-0 -- \
  /usr/lib/postgresql/13/bin/psql -h localhost -U inventory_user -d movies
```

```sql
\dt               -- list tables
SELECT * FROM movies;
\q                -- exit
```

### Billing Database (orders)

```bash
kubectl exec -it billing-database-0 -- \
  /usr/lib/postgresql/13/bin/psql -h localhost -U billing_user -d orders
```

```sql
\l                -- list databases (confirm "orders" exists)
TABLE orders;     -- show all orders
\q                -- exit
```

### One-liner queries (no interactive shell)

```bash
# Show all orders
kubectl exec -it billing-database-0 -- \
  /usr/lib/postgresql/13/bin/psql -h localhost -U billing_user -d orders \
  -c "TABLE orders;"

# Show all movies
kubectl exec -it inventory-database-0 -- \
  /usr/lib/postgresql/13/bin/psql -h localhost -U inventory_user -d movies \
  -c "SELECT id, title FROM movies;"
```

---

## Troubleshooting

### Pods Not Starting

```bash
# Describe a failing pod
kubectl describe pod <pod-name>

# View previous crash logs
kubectl logs <pod-name> --previous

# Check all recent events
kubectl get events --sort-by='.lastTimestamp'
```

### Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| `ImagePullBackOff` | Image not public on Docker Hub | Set image visibility to Public on hub.docker.com |
| `CrashLoopBackOff` | App crashed on startup | Run `kubectl logs <pod> --previous` to see error |
| `Pending` pod | Node out of memory/CPU | Run `kubectl describe node` and check `Conditions` |
| `Evicted` pods | Node disk pressure | Run `vagrant ssh <node> -- df -h` to check disk |
| HPA shows `<unknown>` CPU | metrics-server not ready | Wait 2–3 minutes after deploy |
| Gateway returns 502 | inventory-app not reachable | Check `kubectl logs <gateway-pod>` for connection error |
| Orders not appearing in DB | billing-app not consuming | Check `kubectl logs billing-app-0` for RabbitMQ connection |

### Clean Up Evicted/Error Pods

```bash
kubectl get pods | grep Evicted | awk '{print $1}' | xargs kubectl delete pod
kubectl get pods | grep Error | awk '{print $1}' | xargs kubectl delete pod
```

### Full Reset

```bash
./orchestrator.sh stop
vagrant destroy -f
./orchestrator.sh create
```

---

## Security

- **No hardcoded credentials** — all passwords stored in Kubernetes Secrets
- **Base64 encoding** — all secret values encoded in `secrets.yaml`
- **`.env` file** — excluded from Git via `.gitignore`, for local development only
- **Specific image tags** — all images use `:1.0` tags, never `:latest`
- **ClusterIP for internal services** — databases and apps are not exposed externally; only the API Gateway is exposed via NodePort

---

## Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [K3s Quick Start](https://docs.k3s.io/quick-start)
- [Vagrant Documentation](https://developer.hashicorp.com/vagrant/docs)
- [RabbitMQ Tutorials](https://www.rabbitmq.com/tutorials)
- [HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [StatefulSet Basics](https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/)

---

**Author:** Hussain Saddam  
**Stack:** K3s · Python/Flask · PostgreSQL · RabbitMQ · Vagrant · VirtualBox  
**Last Updated:** April 2026
