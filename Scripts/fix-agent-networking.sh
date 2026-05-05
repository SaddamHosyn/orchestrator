#!/bin/bash
# Fix K3s Agent Node Networking Configuration
# Run this on the agent node to reconfigure it with the correct IP

set -e

echo "=========================================="
echo "Fixing K3s Agent Node Networking"
echo "=========================================="

# Step 1: Drain the node from master perspective
echo "Step 1: Draining agent node from cluster..."
kubectl drain agent --ignore-daemonsets --delete-emptydir-data --force 2>/dev/null || true
sleep 5

# Step 2: Delete the node to force rejoin
echo "Step 2: Removing agent node from cluster..."
kubectl delete node agent || true
sleep 5

# Step 3: SSH into agent and reset K3s configuration
echo "Step 3: Resetting K3s agent configuration..."
vagrant ssh agent <<'EOF'
set -e
echo "Stopping K3s agent service..."
sudo systemctl stop k3s-agent || true
sleep 2

echo "Removing K3s agent data..."
sudo rm -rf /var/lib/rancher/k3s || true
sudo rm -rf /etc/rancher/k3s || true
sleep 2

echo "Verifying network interface..."
echo "enp0s8 interface configuration:"
ip addr show enp0s8

echo "K3s agent configuration reset complete. Service will restart automatically..."
EOF

# Step 4: Wait for agent to rejoin
echo "Step 4: Waiting for agent node to rejoin cluster..."
for i in {1..60}; do
  echo "Checking node status (attempt $i/60)..."
  if kubectl get nodes agent 2>/dev/null | grep -q "Ready"; then
    echo "✓ Agent node is Ready!"
    break
  fi
  sleep 5
done

# Step 5: Verify the IP
echo "Step 5: Verifying agent node configuration..."
kubectl get nodes agent -o wide

echo "=========================================="
echo "Agent Node Fix Complete"
echo "=========================================="
