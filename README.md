# Orchestrator: Kubernetes Microservices Deployment

A complete Kubernetes (K3s) cluster setup for deploying microservices across a distributed system. This project demonstrates containerization, infrastructure-as-code, Kubernetes orchestration, and DevOps best practices.

## Project Overview

This project migrates a microservices architecture from a 3-VM Docker Compose setup to a production-ready K3s Kubernetes cluster running on 2 VMs (1 master, 1 worker). It includes six core services that communicate through APIs and message queues.

### Architecture

```
┌─────────────────────────────────────────────────────┐
│           Kubernetes Cluster (K3s)                  │
│  ┌──────────────────────────────────────────────┐   │
│  │ Master Node (192.168.56.10)                  │   │
│  │  - K3s Server                                │   │
│  │  - API Server                                │   │
│  │  - Scheduler                                 │   │
│  └──────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────┐   │
│  │ Worker Node (192.168.56.11)                  │   │
│  │  - K3s Agent                                 │   │
│  │  - Pods Deployment:                          │   │
│  │    • API Gateway (Deployment, HPA)           │   │
│  │    • Inventory App (Deployment, HPA)         │   │
│  │    • Billing App (StatefulSet)               │   │
│  │    • Inventory Database (StatefulSet)        │   │
│  │    • Billing Database (StatefulSet)          │   │
│  │    • RabbitMQ (Deployment)                   │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
       ↓
   PersistentVolumes for Databases
   Kubernetes Secrets for Credentials
   HPA for Auto-scaling
```

## Services

| Service              | Type        | Replicas  | Port | Purpose                                         |
| -------------------- | ----------- | --------- | ---- | ----------------------------------------------- |
| `api-gateway-app`    | Deployment  | 1-3 (HPA) | 3000 | API Gateway - forwards requests to all services |
| `inventory-app`      | Deployment  | 1-3 (HPA) | 8080 | Inventory management API                        |
| `billing-app`        | StatefulSet | 1         | 8080 | Billing and order processing                    |
| `rabbitmq`           | Deployment  | 1         | 5672 | Message queue broker                            |
| `inventory-database` | StatefulSet | 1         | 5432 | PostgreSQL for inventory                        |
| `billing-database`   | StatefulSet | 1         | 5432 | PostgreSQL for billing                          |

## Prerequisites

### System Requirements

- **macOS, Linux, or Windows** with virtualization support
- **RAM**: At least 4-5 GB free (for 2 VMs)
- **Disk Space**: 20+ GB free for VMs and images

### Software Requirements

1. **VirtualBox** 7.0+

   ```bash
   # macOS (using Homebrew)
   brew install virtualbox
   ```

2. **Vagrant** 2.4+

   ```bash
   # macOS (using Homebrew)
   brew install vagrant
   ```

3. **kubectl** (on your local machine)

   ```bash
   # macOS (using Homebrew)
   brew install kubectl
   ```

4. **Docker** (optional, for building images locally)
   ```bash
   # macOS (using Homebrew)
   brew install docker
   ```

### Kubernetes Knowledge

Before starting, read the official documentation:

- [Kubernetes Core Concepts](https://kubernetes.io/docs/concepts/overview/what-is-kubernetes/)
- [K3s Documentation](https://docs.k3s.io/)
- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

## Project Structure

```
orchestrator/
├── Vagrantfile                      # VM configuration for K3s cluster
├── orchestrator.sh                  # Management script (create/start/stop)
│
├── Scripts/
│   ├── master.sh                    # K3s server setup
│   ├── agent.sh                     # K3s worker setup
│   └── k3s-node-token              # Generated token (shared during setup)
│
├── Manifests/                       # Kubernetes YAML manifests
│   ├── secrets.yaml                 # Database and RabbitMQ credentials
│   ├── inventory-db-statefulset.yaml
│   ├── billing-db-statefulset.yaml
│   ├── billing-app-statefulset.yaml
│   ├── rabbitmq-deployment.yaml
│   ├── inventory-app-deployment.yaml
│   ├── api-gateway-deployment.yaml
│   └── hpa.yaml                     # Auto-scaling rules
│
├── srcs/                            # Application source code
│   ├── api-gateway-app/
│   ├── inventory-app/
│   ├── billing-app/
│   ├── inventory-database/
│   ├── billing-database/
│   └── rabbitmq-service/
│
├── .env                             # Environment variables (credentials)
├── docker-compose.yml               # (Legacy - for reference)
├── README.md                        # This file
├── allstepsneed.md                  # Detailed implementation guide
└── Architecture.png                 # System architecture diagram
```

## Configuration

### Environment Variables (.env)

The `.env` file contains all credentials and configuration:

```env
# Inventory Database
INVENTORY_DB_NAME=movies
INVENTORY_DB_USER=inventory_user
INVENTORY_DB_PASSWORD=inventory_pass

# Billing Database
BILLING_DB_NAME=orders
BILLING_DB_USER=billing_user
BILLING_DB_PASSWORD=billing_pass

# RabbitMQ
RABBITMQ_USER=billing_rmq
RABBITMQ_PASSWORD=billing_rmq_pass
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_QUEUE=billing_queue

# API Ports
INVENTORY_PORT=8080
BILLING_PORT=8081
GATEWAY_PORT=3000
```

**IMPORTANT**: Never commit `.env` to git. It's already in `.gitignore`.

### Kubernetes Secrets

All credentials are stored in `Manifests/secrets.yaml` as Kubernetes Secret objects. Values are base64-encoded for security.

Example:

```bash
# To encode a value
echo -n "mypassword" | base64
# Output: bXlwYXNzd29yZA==

# To decode
echo "bXlwYXNzd29yZA==" | base64 -d
```

### Docker Images

All services must be pushed to Docker Hub before deployment. Update image references in manifests:

```yaml
image: yourusername/api-gateway:1.0
```

Replace `yourusername` with your Docker Hub username.

## Setup & Deployment

### Step 1: Prepare Docker Images

Push all 6 images to Docker Hub:

```bash
# Navigate to each service directory and build/push
docker build -t yourusername/api-gateway:1.0 ./srcs/api-gateway-app/
docker push yourusername/api-gateway:1.0

# Repeat for all services:
# - yourusername/inventory-app:1.0
# - yourusername/billing-app:1.0
# - yourusername/inventory-database:1.0
# - yourusername/billing-database:1.0
# - yourusername/rabbitmq:1.0
```

**Ensure all images are PUBLIC on Docker Hub** for the cluster to pull them.

### Step 2: Update Manifests

Edit manifest files to replace `yourusername` with your Docker Hub username:

```bash
sed -i 's/yourusername/YOUR_DOCKER_HUB_USERNAME/g' Manifests/*.yaml
```

### Step 3: Create the Cluster

```bash
./orchestrator.sh create
```

This will:

- Launch 2 Debian VMs (master and agent)
- Install K3s on both nodes
- Verify the cluster is ready
- Download and configure `kubectl`

Expected output:

```
NAME     STATUS   ROLES                  AGE   VERSION
master   Ready    control-plane,master   30s   v1.28.x
agent    Ready    <none>                 20s   v1.28.x
```

### Step 4: Deploy Services

```bash
./orchestrator.sh start
```

This will:

- Resume the VMs
- Apply all Kubernetes manifests
- Deploy services, databases, and queues
- Configure auto-scaling (HPA)

### Step 5: Verify Deployment

```bash
# Check all pods
kubectl get pods -o wide

# Check services
kubectl get svc

# Check deployments
kubectl get deployments

# Check StatefulSets
kubectl get statefulsets

# Check persistent volumes
kubectl get pv

# Check HPA status
kubectl get hpa
```

Expected output (10+ pods running):

```
NAME                                READY   STATUS    RESTARTS   AGE
api-gateway-app-xxxxx               1/1     Running   0          5m
inventory-app-xxxxx                 1/1     Running   0          5m
billing-app-0                       1/1     Running   0          5m
rabbitmq-xxxxx                      1/1     Running   0          5m
inventory-database-0                1/1     Running   0          5m
billing-database-0                  1/1     Running   0          5m
```

## Usage

### Accessing Services

#### API Gateway (External Access)

```bash
# Access from your local machine
curl http://192.168.56.10:30000/health

# Or use the Postman collection
# See: CRUD_Master.postman_collection.json
```

#### Internal Service Communication

From within the cluster, services communicate using their DNS names:

- `api-gateway-app:3000`
- `inventory-app:8080`
- `billing-app:8080`
- `rabbitmq:5672`
- `inventory-database:5432`
- `billing-database:5432`

### Monitoring & Debugging

#### View Pod Logs

```bash
# Follow real-time logs
./orchestrator.sh logs api-gateway-app-xxxxx

# Or using kubectl
kubectl logs -f pod-name
```

#### SSH Into a Node

```bash
# SSH into master node
vagrant ssh master

# SSH into agent node
vagrant ssh agent
```

#### Execute Command in Pod

```bash
kubectl exec -it pod-name -- /bin/sh
```

#### Check Pod Details

```bash
kubectl describe pod pod-name
```

### Cluster Status

Check cluster health:

```bash
./orchestrator.sh status
```

This shows:

- Node status (Ready/NotReady)
- Pod status
- Service endpoints
- API Gateway access URL

### Scaling

HPA automatically scales based on CPU:

```bash
# Check HPA status
kubectl get hpa

# Manually scale (overrides HPA temporarily)
kubectl scale deployment api-gateway-app --replicas=2

# View HPA events
kubectl describe hpa api-gateway-app-hpa
```

### Stopping the Cluster

```bash
./orchestrator.sh stop
```

This will:

- Delete all deployed resources
- Suspend the VMs (can be resumed later)
- Clean up

**Note**: VMs are suspended, not destroyed. You can resume with:

```bash
./orchestrator.sh start
```

## Database Management

### Connect to Inventory Database

```bash
# From your local machine
psql -h 192.168.56.10 -p 5432 -U inventory_user -d movies
# Password: inventory_pass

# From within a pod
kubectl exec -it inventory-database-0 -- psql -U inventory_user -d movies
```

### Connect to Billing Database

```bash
psql -h 192.168.56.10 -p 5432 -U billing_user -d orders
# Password: billing_pass
```

### Database Schema

Update the Dockerfiles to include schema initialization SQL files:

```dockerfile
COPY init.sql /docker-entrypoint-initdb.d/
```

This automatically runs SQL on container startup.

## Troubleshooting

### VMs Not Starting

```bash
# Check VirtualBox status
VBoxManage list vms

# Increase available RAM or reduce VM memory in Vagrantfile
# Default: master 2GB, agent 1GB
```

### Pods Not Running

```bash
# Check pod status and errors
kubectl describe pod pod-name

# Check node resources
kubectl describe node node-name

# Check image pull errors
kubectl get events --sort-by='.lastTimestamp'
```

### Services Not Communicating

```bash
# Test DNS resolution
kubectl exec -it pod-name -- nslookup service-name

# Test connectivity
kubectl exec -it pod-name -- curl http://other-service:port
```

### HPA Not Scaling

```bash
# Verify metrics-server is running (K3s includes it by default)
kubectl get deployment metrics-server -n kube-system

# Check resource requests are set (required for HPA)
kubectl describe deployment api-gateway-app
# Must have resources.requests.cpu defined
```

### Database Connection Issues

```bash
# Verify secrets are created
kubectl get secrets

# Check secret values (base64 encoded)
kubectl get secret inventory-db-secret -o yaml

# Test database pod connectivity
kubectl exec -it inventory-database-0 -- psql -U inventory_user -d movies -c '\dt'
```

## Performance Optimization

### Resource Requests & Limits

Each pod has resource constraints:

```yaml
resources:
  requests:
    cpu: "100m" # Minimum guaranteed
    memory: "256Mi"
  limits:
    cpu: "500m" # Maximum allowed
    memory: "512Mi"
```

Adjust based on actual workload.

### HPA Tuning

Edit `Manifests/hpa.yaml` to adjust scaling thresholds:

```yaml
averageUtilization: 60 # Scale up when CPU > 60%
maxReplicas: 3 # Maximum 3 pods
minReplicas: 1 # Minimum 1 pod
```

### PersistentVolume Performance

Databases use local storage. For better performance in production:

- Use NFS-backed PVs
- Enable caching policies
- Monitor disk I/O

## Security Considerations

1. **Secrets Management**
   - Keep `.env` file secure (already in `.gitignore`)
   - Never commit secrets to git
   - Use Kubernetes Secret objects in production

2. **Network Policies**
   - Consider adding NetworkPolicies to restrict traffic
   - Databases should not accept external connections

3. **Image Security**
   - Scan images for vulnerabilities
   - Use specific version tags (not `latest`)
   - Sign images with cosign

4. **RBAC**
   - Configure service accounts for applications
   - Implement role-based access control

## Advanced Topics

### Adding Kubernetes Dashboard

Monitor your cluster visually:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Access dashboard
kubectl proxy
# Visit: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

### Logging with Loki + Grafana

Deploy a logging stack:

```bash
# Add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Loki
helm install loki grafana/loki-stack -n monitoring --create-namespace
```

### Ingress Controller

Replace NodePort with Ingress for better routing:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway-ingress
spec:
  ingressClassName: traefik
  rules:
    - host: api.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-gateway-app
                port:
                  number: 3000
```

## Maintenance

### Backup & Recovery

```bash
# Backup all manifests
tar -czf manifests-backup.tar.gz Manifests/

# Backup Vagrant VMs
VBoxManage export master -o master-backup.ova
VBoxManage export agent -o agent-backup.ova
```

### Updating Images

To deploy a new version:

1. Build and push new image
2. Update image tag in manifest
3. Apply updated manifest

```bash
kubectl apply -f Manifests/api-gateway-deployment.yaml
```

K3s will automatically trigger a rolling update.

### Cluster Upgrades

K3s handles updates automatically. Monitor version:

```bash
kubectl get nodes -o wide
```

## Learning Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [K3s Quick Start](https://docs.k3s.io/quick-start)
- [Vagrant Documentation](https://www.vagrantup.com/docs)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [PostgreSQL Docker Image](https://hub.docker.com/_/postgres)
- [RabbitMQ Docker Image](https://hub.docker.com/_/rabbitmq)

## Project Timeline

This project demonstrates:

1. **Containerization** - Dockerfile best practices
2. **Orchestration** - Kubernetes resource management
3. **Infrastructure as Code** - Vagrant + YAML manifests
4. **Monitoring & Scaling** - HPA auto-scaling
5. **Data Persistence** - StatefulSets + PersistentVolumes
6. **Security** - Kubernetes Secrets management
7. **DevOps Workflows** - Automated deployment pipeline

## Contributing

To improve this project:

1. Test all manifest updates
2. Document configuration changes
3. Update README with new features
4. Maintain clean, idiomatic YAML

## Support

For issues or questions:

1. Check the Troubleshooting section
2. Review Kubernetes documentation
3. Inspect pod logs and events
4. Review allstepsneed.md for implementation details

---

**Last Updated**: April 2026
**Kubernetes Version**: K3s (Latest)
**Vagrant**: 2.4+
**VirtualBox**: 7.0+
