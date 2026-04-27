#!/bin/bash
# K3s Master Node Setup Script

set -e

echo "=========================================="
echo "Setting up K3s Master Node"
echo "=========================================="

# Update package lists (but skip full upgrade for speed)
apt-get update
apt-get install -y curl wget git

# Install K3s server (master)
echo "Installing K3s server..."
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --disable servicelb \
  --disable traefik \
  --tls-san 192.168.56.10 \
  --advertise-address 192.168.56.10 \
  --node-ip 192.168.56.10

# Wait for K3s to be ready
echo "Waiting for K3s server to be ready..."
sleep 10

# Export kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Verify K3s installation
echo "Verifying K3s installation..."
/usr/local/bin/k3s kubectl get nodes

# Get the node token for agent to join
echo "Extracting K3s server token..."
K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)
echo "K3s server is ready!"
echo "Token will be available at /var/lib/rancher/k3s/server/node-token"

# Save token to shared folder so agent can read it
mkdir -p /home/vagrant/project/Scripts
cp /var/lib/rancher/k3s/server/node-token /home/vagrant/project/Scripts/k3s-node-token 2>/dev/null || true

echo "=========================================="
echo "K3s Master Node Setup Complete"
echo "=========================================="
