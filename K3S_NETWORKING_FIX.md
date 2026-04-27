# 🔧 CRITICAL FIX: K3s Node IP Configuration

## Problem Identified

**Error**: "No route to host" when pods on different K3s nodes try to communicate

```
(psycopg2.OperationalError) connection to server at "inventory-database"
(10.42.3.22), port 5432 failed: No route to host
```

**Root Cause**: Both K3s nodes reporting INTERNAL-IP as `10.0.2.15` instead of their private network addresses:

- Master should be: `192.168.56.10`
- Agent should be: `192.168.56.11`

This causes Flannel overlay network to misconfigure and prevent pod-to-pod communication across nodes.

---

## Solution Applied

Updated `Scripts/master.sh` and `Scripts/agent.sh` with explicit node IP configuration:

### ✅ Changes Made

**Scripts/master.sh**:

```bash
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --disable servicelb \
  --disable traefik \
  --tls-san 192.168.56.10 \
  --advertise-address 192.168.56.10 \     # ← NEW
  --node-ip 192.168.56.10                  # ← NEW
```

**Scripts/agent.sh**:

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.10:6443 K3S_TOKEN="${K3S_TOKEN}" sh -s - \
  --node-ip 192.168.56.11                  # ← NEW
```

---

## Implementation Steps

### Step 1: Restart K3s Services (Current Cluster)

```bash
# On Master Node
vagrant ssh master -c "sudo systemctl restart k3s"

# Wait for master to stabilize
sleep 15

# On Agent Node
vagrant ssh agent -c "sudo systemctl restart k3s-agent"

# Wait for agent to reconnect
sleep 30
```

### Step 2: Verify Node IP Configuration

```bash
kubectl get nodes -o wide

# Expected output:
# NAME     STATUS   ROLES           INTERNAL-IP    EXTERNAL-IP   OS-IMAGE
# master   Ready    control-plane   192.168.56.10  <none>        Ubuntu 24.04.1 LTS
# agent    Ready    <none>          192.168.56.11  <none>        Ubuntu 24.04.1 LTS
```

**✅ If INTERNAL-IP shows 192.168.56.x → Networking is fixed!**

### Step 3: Restart Pods to Reconnect Network

```bash
# Restart all pods to reconnect to fixed overlay network
kubectl rollout restart deployment/api-gateway-app
kubectl rollout restart deployment/inventory-app
kubectl rollout restart deployment/rabbitmq

# Wait for pods to stabilize
sleep 20

# Check pod status
kubectl get pods -o wide
```

### Step 4: Verify Pod-to-Pod Connectivity

```bash
# Test from inventory-app pod to inventory-database
kubectl exec -it $(kubectl get pods -l app=inventory-app -o jsonpath='{.items[0].metadata.name}') -- \
  python3 -c "import socket; s = socket.socket(); s.connect(('inventory-database', 5432)); print('✅ Connected to database!')"
```

### Step 5: Test API Endpoints

```bash
# GET /api/movies (should work now!)
curl -s http://192.168.56.10:30000/api/movies/ | jq .

# Expected: JSON array of movies (or empty array if no movies added)
# NOT: "No route to host" error
```

---

## Validation Checklist

- [ ] `kubectl get nodes -o wide` shows INTERNAL-IP 192.168.56.10/11
- [ ] `kubectl get pods -o wide` shows all pods 1/1 Ready
- [ ] Pod connectivity test succeeds (Step 4)
- [ ] GET /api/movies returns 200 (not 502)
- [ ] GET /api/movies returns valid JSON (even if empty)
- [ ] `curl http://192.168.56.10:30000/ready` returns 200

---

## Quick Fix Command (All-in-One)

```bash
#!/bin/bash
echo "Fixing K3s node IP configuration..."

echo "Step 1: Restarting K3s master..."
vagrant ssh master -c "sudo systemctl restart k3s"
sleep 15

echo "Step 2: Restarting K3s agent..."
vagrant ssh agent -c "sudo systemctl restart k3s-agent"
sleep 30

echo "Step 3: Verifying node IPs..."
kubectl get nodes -o wide

echo ""
echo "Step 4: Restarting pods..."
kubectl rollout restart deployment/api-gateway-app
kubectl rollout restart deployment/inventory-app
kubectl rollout restart deployment/rabbitmq
sleep 20

echo ""
echo "Step 5: Checking pod status..."
kubectl get pods

echo ""
echo "✅ Fix complete! Test with: curl http://192.168.56.10:30000/api/movies/"
```

---

## Expected Results After Fix

### 📊 Cluster Status

```
✅ kubectl get nodes -o wide
NAME     STATUS   ROLES           INTERNAL-IP    EXTERNAL-IP   VERSION
master   Ready    control-plane   192.168.56.10  <none>        v1.34.6+k3s1
agent    Ready    <none>          192.168.56.11  <none>        v1.34.6+k3s1

✅ kubectl get pods
NAME                               READY   STATUS    RESTARTS
api-gateway-app-xxxxxxxxxx         1/1     Running   0
inventory-app-xxxxxxxxxx           1/1     Running   0
billing-app-0                      1/1     Running   0
inventory-database-0               1/1     Running   0
billing-database-0                 1/1     Running   0
rabbitmq-xxxxxxxxxx                1/1     Running   0
```

### 🌐 Network Connectivity

```
✅ Pod-to-pod communication across nodes working
✅ Service discovery working (inventory-database resolves to 10.42.3.22)
✅ Database connectivity working
```

### 🚀 API Endpoints

```
✅ GET http://192.168.56.10:30000/ready → 200 OK
✅ GET http://192.168.56.10:30000/api/movies/ → 200 OK (returns JSON)
✅ POST http://192.168.56.10:30000/api/billing/ → 200 OK (publishes to RabbitMQ)
```

---

## Why This Fix Works

**Before Fix**:

- Both nodes report INTERNAL-IP: 10.0.2.15 (VirtualBox NAT interface)
- Flannel sees both nodes as same IP
- Overlay network CIDR (10.42.x.x) cannot route between real nodes
- Pods on different nodes: "No route to host"

**After Fix**:

- Master node reports INTERNAL-IP: 192.168.56.10
- Agent node reports INTERNAL-IP: 192.168.56.11
- Flannel correctly maps pod IPs to node IPs
- Pod-to-pod traffic routes correctly through Flannel overlay network
- Connectivity: ✅ Restored

---

## For Future Cluster Recreations

When running `./orchestrator.sh create`, the updated scripts will automatically include the correct node IP configuration. No manual fixes needed!

---

**Status**: Ready for implementation  
**Time to Apply**: ~2 minutes  
**Impact**: Restores full pod-to-pod networking  
**Risk Level**: Low (K3s services only, no data loss)

---

**Next Steps**:

1. Run the fix command above
2. Verify with `kubectl get nodes -o wide`
3. Test API endpoints
4. Project is now fully functional! ✅
