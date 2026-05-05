#!/bin/bash
# Quick fix for K3s agent networking without full re-provisioning
# This script runs via SSH on the agent to fix IP binding issues

set -e

echo "🔧 Fixing K3s agent networking configuration..."

# Read the K3s token from shared folder
K3S_TOKEN_FILE="/home/vagrant/project/Scripts/k3s-node-token"
if [ ! -f "$K3S_TOKEN_FILE" ]; then
    echo "❌ ERROR: K3s token not found at $K3S_TOKEN_FILE"
    exit 1
fi

K3S_TOKEN=$(cat "$K3S_TOKEN_FILE")
echo "📝 Token retrieved: ${K3S_TOKEN:0:20}..."

# Verify the private network interface
echo "🔍 Checking network interface..."
if ! ip addr show enp0s8 | grep -q "192.168.56.11"; then
    echo "❌ ERROR: enp0s8 does not have IP 192.168.56.11"
    ip addr show enp0s8
    exit 1
fi
echo "✓ enp0s8 configured with 192.168.56.11"

# Stop K3s agent service
echo "⏹️  Stopping K3s agent..."
sudo systemctl stop k3s-agent || true
sleep 2

# Remove old K3s state but keep the service/config
echo "🗑️  Cleaning K3s state..."
sudo rm -rf /var/lib/rancher/k3s/agent/containerd /var/lib/rancher/k3s/agent/etc || true
sudo rm -rf /var/lib/rancher/k3s/agent/var || true

# Restart K3s agent - it will rejoin with correct networking
echo "🚀 Starting K3s agent..."
sudo systemctl start k3s-agent

echo "⏳ Waiting for K3s agent to stabilize..."
sleep 5

# Check if service is running
if sudo systemctl is-active k3s-agent > /dev/null 2>&1; then
    echo "✅ K3s agent service is running"
else
    echo "⚠️  K3s agent service may still be starting..."
fi

echo "✅ K3s agent networking fix complete!"
