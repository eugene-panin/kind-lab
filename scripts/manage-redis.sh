#!/bin/bash

# Redis Management Script for kind-lab
# Handles installation, upgrade, uninstallation, status checking, and log viewing

set -e

# Configuration
RELEASE_NAME="redis"
NAMESPACE="redis"
CHART_NAME="bitnami/redis"
CHART_VERSION="18.0.0"  # Update this to the latest version

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install Helm first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if cluster is running
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Kubernetes cluster is not accessible. Please start the cluster first."
        exit 1
    fi
    
    print_status "Prerequisites check passed."
}

# Function to load environment variables
load_env() {
    if [ -f .env ]; then
        print_status "Loading environment variables from .env file..."
        export $(cat .env | grep -v '^#' | xargs)
    else
        print_warning ".env file not found. Using default values."
    fi
    
    # Set defaults if not provided
    LOCAL_DOMAIN=${LOCAL_DOMAIN:-beavers.dev}
}

# Function to add Helm repository
add_repo() {
    print_status "Adding Bitnami Helm repository..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
}

# Function to create namespace
create_namespace() {
    print_status "Creating namespace: $NAMESPACE"
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
}

# Function to copy TLS certificates
copy_tls_certs() {
    print_status "Copying TLS certificates to $NAMESPACE namespace..."
    
    # Copy the wildcard certificate
    if kubectl get secret wildcard-tls -n cert-manager &> /dev/null; then
        kubectl get secret wildcard-tls -n cert-manager -o yaml | \
            sed "s/namespace: cert-manager/namespace: $NAMESPACE/" | \
            sed "s/name: wildcard-tls/name: redis-tls/" | \
            kubectl apply -f -
        print_status "TLS certificates copied successfully."
    else
        print_warning "TLS certificate not found in cert-manager namespace."
    fi
}

# Function to install Redis
install() {
    print_header "Installing Redis"
    
    check_prerequisites
    load_env
    add_repo
    create_namespace
    copy_tls_certs
    
    print_status "Installing Redis with Helm..."
    
    # Create values file with environment substitution
    VALUES_FILE="/tmp/redis-values.yaml"
    envsubst < extensions/redis/values.yaml > $VALUES_FILE
    
    helm install $RELEASE_NAME $CHART_NAME \
        --namespace $NAMESPACE \
        --version $CHART_VERSION \
        --values $VALUES_FILE \
        --wait \
        --timeout 10m
    
    print_status "Redis installation completed!"
    print_status "Access URL: https://redis.$LOCAL_DOMAIN"
    print_status "Redis endpoint: redis-master.redis.svc.cluster.local:6379"
    print_status "Port-forward: kubectl port-forward -n redis svc/redis-master 6380:6379"
    
    # Clean up temporary file
    rm -f $VALUES_FILE
}

# Function to upgrade Redis
upgrade() {
    print_header "Upgrading Redis"
    
    check_prerequisites
    load_env
    add_repo
    
    print_status "Upgrading Redis with Helm..."
    
    # Create values file with environment substitution
    VALUES_FILE="/tmp/redis-values.yaml"
    envsubst < extensions/redis/values.yaml > $VALUES_FILE
    
    helm upgrade $RELEASE_NAME $CHART_NAME \
        --namespace $NAMESPACE \
        --version $CHART_VERSION \
        --values $VALUES_FILE \
        --wait \
        --timeout 10m
    
    print_status "Redis upgrade completed!"
    
    # Clean up temporary file
    rm -f $VALUES_FILE
}

# Function to uninstall Redis
uninstall() {
    print_header "Uninstalling Redis"
    
    print_status "Uninstalling Redis with Helm..."
    helm uninstall $RELEASE_NAME --namespace $NAMESPACE --wait
    
    print_status "Deleting namespace: $NAMESPACE"
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    
    print_status "Redis uninstallation completed!"
}

# Function to show status
status() {
    print_header "Redis Status"
    
    echo "Namespace: $NAMESPACE"
    echo ""
    
    echo "Pods:"
    kubectl get pods -n $NAMESPACE
    echo ""
    
    echo "Services:"
    kubectl get services -n $NAMESPACE
    echo ""
    
    echo "Ingress:"
    kubectl get ingress -n $NAMESPACE
    echo ""
    
    echo "Secrets:"
    kubectl get secrets -n $NAMESPACE
    echo ""
    
    echo "Persistent Volumes:"
    kubectl get pvc -n $NAMESPACE
    echo ""
    
    # Check if Redis is ready
    if kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=redis --no-headers | grep -q "Running"; then
        print_status "Redis is running and ready!"
        print_status "Access URL: https://redis.$LOCAL_DOMAIN"
        print_status "Redis endpoint: redis-master.redis.svc.cluster.local:6379"
    else
        print_warning "Redis is not ready yet. Check the logs for more information."
    fi
}

# Function to show logs
logs() {
    print_header "Redis Logs"
    
    # Get the Redis pod name
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=redis -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$POD_NAME" ]; then
        print_error "No Redis pods found in namespace $NAMESPACE"
        exit 1
    fi
    
    print_status "Showing logs for pod: $POD_NAME"
    kubectl logs -n $NAMESPACE $POD_NAME -f
}

# Function to test Redis connection
test_connection() {
    print_header "Testing Redis Connection"
    
    # Get Redis pod name
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=redis -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$POD_NAME" ]; then
        print_error "No Redis pods found in namespace $NAMESPACE"
        exit 1
    fi
    
    print_status "Testing Redis connection..."
    kubectl exec -n $NAMESPACE $POD_NAME -- redis-cli ping
    
    if [ $? -eq 0 ]; then
        print_status "Redis connection successful!"
    else
        print_error "Redis connection failed!"
    fi
}

# Function to show Redis info
info() {
    print_header "Redis Info"
    
    # Get Redis pod name
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=redis -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$POD_NAME" ]; then
        print_error "No Redis pods found in namespace $NAMESPACE"
        exit 1
    fi
    
    print_status "Redis server info:"
    kubectl exec -n $NAMESPACE $POD_NAME -- redis-cli info server
    
    echo ""
    print_status "Redis memory info:"
    kubectl exec -n $NAMESPACE $POD_NAME -- redis-cli info memory
    
    echo ""
    print_status "Redis keyspace info:"
    kubectl exec -n $NAMESPACE $POD_NAME -- redis-cli info keyspace
}

# Function to show help
show_help() {
    echo "Redis Management Script for kind-lab"
    echo ""
    echo "Usage: $0 {install|upgrade|uninstall|status|logs|test|info}"
    echo ""
    echo "Commands:"
    echo "  install   - Install Redis with UI"
    echo "  upgrade   - Upgrade Redis to latest version"
    echo "  uninstall - Uninstall Redis"
    echo "  status    - Show Redis status"
    echo "  logs      - Show Redis logs"
    echo "  test      - Test Redis connection"
    echo "  info      - Show Redis server info"
    echo ""
    echo "Environment variables (load from .env file):"
    echo "  LOCAL_DOMAIN   - Local domain (default: beavers.dev)"
    echo ""
    echo "Access URL: https://redis.\$LOCAL_DOMAIN"
    echo "Redis endpoint: redis-master.redis.svc.cluster.local:6379"
    echo "Port-forward: kubectl port-forward -n redis svc/redis-master 6380:6379"
}

# Main script logic
case "${1:-}" in
    install)
        install
        ;;
    upgrade)
        upgrade
        ;;
    uninstall)
        uninstall
        ;;
    status)
        status
        ;;
    logs)
        logs
        ;;
    test)
        test_connection
        ;;
    info)
        info
        ;;
    *)
        show_help
        exit 1
        ;;
esac 