#!/bin/bash

# K3s Orchestrator Management Script
# Manages the lifecycle of the Kubernetes cluster: create, start, stop

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/Manifests"
KUBECONFIG_PATH="$HOME/.kube/config"

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to deploy all K8s manifests in correct dependency order
deploy_manifests() {
    log_info "Deploying manifests..."

    if [ ! -d "$MANIFESTS_DIR" ]; then
        log_error "Manifests directory not found at $MANIFESTS_DIR"
        exit 1
    fi

    # Apply secrets first
    kubectl apply -f "$MANIFESTS_DIR/secrets.yaml"
    sleep 2

    # Apply database manifests
    kubectl apply -f "$MANIFESTS_DIR/inventory-db-statefulset.yaml"
    kubectl apply -f "$MANIFESTS_DIR/billing-db-statefulset.yaml"

    # Wait for databases to initialize
    log_info "Waiting for databases to be ready..."
    sleep 5

    # Apply RabbitMQ
    kubectl apply -f "$MANIFESTS_DIR/rabbitmq-deployment.yaml"
    sleep 3

    # Apply app manifests
    kubectl apply -f "$MANIFESTS_DIR/billing-app-statefulset.yaml"
    kubectl apply -f "$MANIFESTS_DIR/inventory-app-deployment.yaml"
    kubectl apply -f "$MANIFESTS_DIR/api-gateway-deployment.yaml"

    # Apply HPA
    kubectl apply -f "$MANIFESTS_DIR/hpa.yaml"

    log_info "All manifests deployed successfully!"
}

# Wait for Kubernetes API to be reachable (up to 60 seconds)
wait_for_api() {
    log_info "Waiting for Kubernetes API to be ready..."
    for i in {1..30}; do
        if kubectl get nodes >/dev/null 2>&1; then
            log_info "Kubernetes API is ready!"
            return 0
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    log_error "Kubernetes API did not become ready in time."
    log_error "Try './orchestrator.sh status' or './orchestrator.sh reset-agent' if the agent is broken."
    return 1
}

# Function to create the cluster (first time only)
create_cluster() {
    log_info "Creating K3s cluster with Vagrant..."

    if ! command -v vagrant &> /dev/null; then
        log_error "Vagrant is not installed. Please install Vagrant first."
        exit 1
    fi

    cd "$SCRIPT_DIR"
    vagrant up

    log_info "VMs created successfully!"
    log_info "Waiting for cluster to stabilize..."
    sleep 15

    # Setup kubeconfig
    log_info "Setting up kubeconfig..."
    mkdir -p "$(dirname "$KUBECONFIG_PATH")"
    vagrant ssh master -- sudo cat /etc/rancher/k3s/k3s.yaml > "$KUBECONFIG_PATH"
    sed -i '' 's/127.0.0.1/192.168.56.10/' "$KUBECONFIG_PATH"
    chmod 600 "$KUBECONFIG_PATH"
    export KUBECONFIG="$KUBECONFIG_PATH"

    wait_for_api

    log_info "Verifying cluster nodes..."
    kubectl get nodes

    deploy_manifests

    log_info "Cluster created successfully!"
    log_info "Access the API Gateway at: http://192.168.56.10:30000"
}

# Function to start the cluster (after a stop)
start_cluster() {
    log_info "Starting K3s cluster..."

    cd "$SCRIPT_DIR"

    # If agent is aborted, stop and tell the user to reset it
    if vagrant status agent 2>/dev/null | grep -q "aborted"; then
        log_warning "Agent VM is in 'aborted' state."
        log_warning "Run './orchestrator.sh reset-agent' to fix it, then run 'start' again."
        exit 1
    fi

    # Boot VMs
    # Note: vagrant up will only provision on first creation, not on subsequent boots
    # This allows us to keep the fixed provisioning scripts while avoiding re-provisioning the master
    vagrant up

    # Restore kubeconfig if it was lost
    if [ ! -f "$KUBECONFIG_PATH" ]; then
        log_info "Kubeconfig not found, fetching from master..."
        mkdir -p "$(dirname "$KUBECONFIG_PATH")"
        vagrant ssh master -- sudo cat /etc/rancher/k3s/k3s.yaml > "$KUBECONFIG_PATH"
        sed -i '' 's/127.0.0.1/192.168.56.10/' "$KUBECONFIG_PATH"
        chmod 600 "$KUBECONFIG_PATH"
    fi

    export KUBECONFIG="$KUBECONFIG_PATH"

    # Fix agent K3s networking if needed
    log_info "Ensuring agent K3s networking is correct..."
    vagrant ssh agent -- bash /home/vagrant/project/Scripts/fix-agent-k3s.sh || log_warning "Agent K3s fix script had issues, continuing anyway..."

    # Wait for Kubernetes API to actually be up before showing status
    wait_for_api

    log_info "Cluster started successfully!"
    log_info ""
    log_info "Nodes:"
    kubectl get nodes
    log_info ""
    log_info "Pods:"
    kubectl get pods -o wide
    log_info ""
    log_info "Services:"
    kubectl get svc -o wide
    log_info ""
    log_info "Access the API Gateway at: http://192.168.56.10:30000"
}

# Function to stop the cluster
# Uses vagrant halt (clean shutdown) — NOT vagrant suspend
# suspend/resume is unreliable on VirtualBox and causes the master API
# to be unreachable on the next start
stop_cluster() {
    log_info "Stopping K3s cluster..."

    cd "$SCRIPT_DIR"
    vagrant halt

    log_info "Cluster stopped successfully!"
    log_info "Run './orchestrator.sh start' to bring it back up."
}

# Function to reset only the agent VM
# Use this when agent is stuck, aborted, or unresponsive
reset_agent() {
    log_warning "Resetting agent VM..."
    log_warning "This will recreate the agent node."
    log_warning "Database data stored on the agent (local-path PVs) will be lost."

    cd "$SCRIPT_DIR"

    vagrant destroy agent -f
    vagrant up agent

    if [ -f "$KUBECONFIG_PATH" ]; then
        export KUBECONFIG="$KUBECONFIG_PATH"

        log_info "Waiting for agent node to join the cluster..."
        sleep 10

        log_info "Current nodes:"
        kubectl get nodes || true

        log_info "Current pods:"
        kubectl get pods -o wide || true
    else
        log_warning "Kubeconfig not found. Run './orchestrator.sh start' after reset."
    fi

    log_info "Agent reset completed!"
    log_info "Run './orchestrator.sh redeploy' to re-apply manifests if pods are missing."
}

# Function to show cluster status
status_cluster() {
    export KUBECONFIG="$KUBECONFIG_PATH"

    if ! kubectl cluster-info &> /dev/null; then
        log_warning "Cluster is not running or kubeconfig not configured."
        log_warning "Run './orchestrator.sh start' to bring the cluster up."
        return 1
    fi

    log_info "Cluster Status:"
    kubectl get nodes
    log_info ""
    log_info "Pods:"
    kubectl get pods -o wide
    log_info ""
    log_info "Services:"
    kubectl get svc -o wide
}

# Function to redeploy all manifests without touching VMs
redeploy_manifests() {
    export KUBECONFIG="$KUBECONFIG_PATH"

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cluster is not running. Start it first with './orchestrator.sh start'"
        exit 1
    fi

    deploy_manifests

    log_info ""
    log_info "Pods after redeploy:"
    kubectl get pods -o wide
}

# Function to show logs
show_logs() {
    local pod=$1
    if [ -z "$pod" ]; then
        log_error "Please specify a pod name"
        exit 1
    fi

    export KUBECONFIG="$KUBECONFIG_PATH"
    kubectl logs -f "$pod"
}

# Main script logic
case "$1" in
    create)
        create_cluster
        ;;
    start)
        start_cluster
        ;;
    stop)
        stop_cluster
        ;;
    status)
        status_cluster
        ;;
    reset-agent)
        reset_agent
        ;;
    redeploy)
        redeploy_manifests
        ;;
    logs)
        show_logs "$2"
        ;;
    *)
        echo "Usage: $0 {create|start|stop|status|reset-agent|redeploy|logs <pod-name>}"
        echo ""
        echo "Commands:"
        echo "  create              - Create the K3s cluster with VMs (first time only)"
        echo "  start               - Start the cluster after a stop"
        echo "  stop                - Stop the cluster cleanly"
        echo "  status              - Show cluster status"
        echo "  reset-agent         - Destroy and recreate only the agent VM"
        echo "  redeploy            - Re-apply all manifests without touching VMs"
        echo "  logs <pod-name>     - Show logs for a specific pod"
        exit 1
        ;;
esac