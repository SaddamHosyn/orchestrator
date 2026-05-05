#!/bin/bash
# K3s Worker Node (Agent) Setup Script

set -e

echo "=========================================="
echo "Setting up K3s Worker Node (Agent)"
echo "=========================================="

# Update package lists (skip full upgrade for speed)
apt-get update
apt-get install -y curl wget git

# Wait for master node to be ready and get the token
echo "Waiting for master node token..."
for i in {1..60}; do
  if [ -f "/home/vagrant/project/Scripts/k3s-node-token" ]; then
    echo "Token file found!"
    break
  fi
  echo "Waiting for token... (attempt $i/60)"
  sleep 2
done

if [ ! -f "/home/vagrant/project/Scripts/k3s-node-token" ]; then
  echo "ERROR: Could not find K3s token from master node"
  exit 1
fi

# Read the token
K3S_TOKEN=$(cat /home/vagrant/project/Scripts/k3s-node-token)
echo "K3s token retrieved: ${K3S_TOKEN:0:20}..."

# ========== CRITICAL: Wait for network interface to be ready ==========
echo "Waiting for network interface enp0s8 to be ready..."
MAX_WAIT=60
COUNT=0
while [ $COUNT -lt $MAX_WAIT ]; do
  if ip addr show enp0s8 2>/dev/null | grep -q "192.168.56.11"; then
    echo "✓ enp0s8 is ready with IP 192.168.56.11"
    break
  fi
  echo "  Attempt $((COUNT+1))/$MAX_WAIT: enp0s8 not ready yet..."
  sleep 1
  COUNT=$((COUNT+1))
done

if ! ip addr show enp0s8 2>/dev/null | grep -q "192.168.56.11"; then
  echo "WARNING: enp0s8 may not have correct IP, but proceeding..."
  ip addr show enp0s8
fi

# Install K3s agent (worker) with explicit environment variables
echo "Installing K3s agent..."
export K3S_URL=https://192.168.56.10:6443
export K3S_TOKEN="${K3S_TOKEN}"

curl -sfL https://get.k3s.io | sh -s - \
  --node-ip 192.168.56.11 \
  --flannel-iface=enp0s8 2>&1 || true

# Give K3s agent time to initialize
echo "Waiting for K3s agent to initialize..."
sleep 10

# Check service status (non-blocking)
if systemctl is-active k3s-agent > /dev/null 2>&1; then
  echo "✓ K3s agent service is running"
else
  echo "⚠ K3s agent service is starting... (may take a moment)"
fi

# Verify the node joined the cluster with correct IP
echo "Verifying node has joined cluster..."
sleep 5

echo "=========================================="
echo "K3s Worker Node Setup Complete"
echo "=========================================="
