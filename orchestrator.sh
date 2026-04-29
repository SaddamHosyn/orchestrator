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

    # Wait a bit for secrets to be created
    sleep 2

    # Apply database manifests
    kubectl apply -f "$MANIFESTS_DIR/inventory-db-statefulset.yaml"
    kubectl apply -f "$MANIFESTS_DIR/billing-db-statefulset.yaml"

    # Wait for databases to initialize
    log_info "Waiting for databases to be ready..."
    sleep 5

    # Apply RabbitMQ
    kubectl apply -f "$MANIFESTS_DIR/rabbitmq-deployment.yaml"

    # Wait for RabbitMQ
    sleep 3

    # Apply app manifests
    kubectl apply -f "$MANIFESTS_DIR/billing-app-statefulset.yaml"
    kubectl apply -f "$MANIFESTS_DIR/inventory-app-deployment.yaml"
    kubectl apply -f "$MANIFESTS_DIR/api-gateway-deployment.yaml"

    # Apply HPA
    kubectl apply -f "$MANIFESTS_DIR/hpa.yaml"

    log_info "All manifests deployed successfully!"
}

# Function to create the cluster
create_cluster() {
    log_info "Creating K3s cluster with Vagrant..."
    
    # Check if Vagrant is installed
    if ! command -v vagrant &> /dev/null; then
        log_error "Vagrant is not installed. Please install Vagrant first."
        exit 1
    fi
    
    # Create the VMs
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
    
    log_info "Verifying cluster nodes..."
    kubectl get nodes
    
    # Deploy all manifests
    deploy_manifests

    echo "cluster created"
}

# Function to start the cluster
start_cluster() {
    log_info "Starting K3s cluster..."
    
    # Start/resume VMs.
    # NOTE: `vagrant resume` cannot update port forwarding rules, which can
    # fail when host SSH ports collide. `vagrant up --no-provision` is safe
    # for both "already running" and "suspended" states and allows auto-correct.
    cd "$SCRIPT_DIR"
    vagrant up --no-provision
    
    log_info "Waiting for cluster to be ready..."
    sleep 10
    
    # Setup kubeconfig if not exists
    if [ ! -f "$KUBECONFIG_PATH" ]; then
        mkdir -p "$(dirname "$KUBECONFIG_PATH")"
        vagrant ssh master -- sudo cat /etc/rancher/k3s/k3s.yaml > "$KUBECONFIG_PATH"
        sed -i '' 's/127.0.0.1/192.168.56.10/' "$KUBECONFIG_PATH"
        chmod 600 "$KUBECONFIG_PATH"
    fi
    
    export KUBECONFIG="$KUBECONFIG_PATH"
    
    # Deploy all manifests
    deploy_manifests
    
    log_info "Cluster started successfully!"
    log_info ""
    log_info "Cluster Resources:"
    kubectl get all -o wide
    log_info ""
    log_info "Pods Status:"
    kubectl get pods -o wide
    log_info ""
    log_info "Services:"
    kubectl get svc -o wide
    log_info ""
    log_info "Access the API Gateway at: http://192.168.56.10:30000"
}

# Function to stop the cluster
stop_cluster() {
    log_info "Stopping K3s cluster..."
    
    export KUBECONFIG="$KUBECONFIG_PATH"
    
    # Delete manifests
    log_info "Deleting deployed resources..."
    
    if [ -d "$MANIFESTS_DIR" ]; then
        kubectl delete -f "$MANIFESTS_DIR/" || true
    fi
    
    log_info "Suspending VMs..."
    
    # Suspend VMs
    cd "$SCRIPT_DIR"
    vagrant suspend
    
    log_info "Cluster stopped successfully!"
}

# Function to show cluster status
status_cluster() {
    export KUBECONFIG="$KUBECONFIG_PATH"
    
    if ! kubectl cluster-info &> /dev/null; then
        log_warning "Cluster is not running or kubeconfig not configured"
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
    logs)
        show_logs "$2"
        ;;
    *)
        echo "Usage: $0 {create|start|stop|status|logs <pod-name>}"
        echo ""
        echo "Commands:"
        echo "  create              - Create the K3s cluster with VMs"
        echo "  start               - Start the cluster and deploy manifests"
        echo "  stop                - Stop the cluster and delete resources"
        echo "  status              - Show cluster status"
        echo "  logs <pod-name>     - Show logs for a specific pod"
        exit 1
        ;;
esac
