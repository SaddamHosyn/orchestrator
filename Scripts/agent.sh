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

# Install K3s agent (worker)
echo "Installing K3s agent..."
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.10:6443 K3S_TOKEN="${K3S_TOKEN}" sh -s - \
  --node-ip 192.168.56.11

echo "=========================================="
echo "K3s Worker Node Setup Complete"
echo "=========================================="
