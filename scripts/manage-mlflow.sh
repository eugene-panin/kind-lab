#!/bin/bash

# MLflow Management Script for Kind Lab
# Usage: ./scripts/manage-mlflow.sh [install|upgrade|uninstall|status|logs]

set -e

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Default values
LOCAL_DOMAIN=${LOCAL_DOMAIN:-beavers.dev}
NAMESPACE="mlflow"
RELEASE_NAME="mlflow"
CHART_NAME="community-charts/mlflow"
CHART_VERSION="0.1.0"

# MLflow configuration with defaults
MLFLOW_DB_NAME=${MLFLOW_DB_NAME:-mlflow}
MLFLOW_S3_BUCKET=${MLFLOW_S3_BUCKET:-mlflow}
MLFLOW_S3_ENDPOINT_URL=${MLFLOW_S3_ENDPOINT_URL:-http://minio.minio.svc.cluster.local:9000}
MLFLOW_S3_IGNORE_TLS=${MLFLOW_S3_IGNORE_TLS:-true}
MLFLOW_AWS_REGION=${MLFLOW_AWS_REGION:-us-east-1}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if namespace exists
namespace_exists() {
    kubectl get namespace "$NAMESPACE" >/dev/null 2>&1
}

# Function to check if release exists
release_exists() {
    helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"
}

# Function to create MLflow database
create_mlflow_database() {
    print_status "Creating MLflow database in PostgreSQL..."
    
    # Wait for PostgreSQL to be ready
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n postgresql --timeout=300s
    
    # Create MLflow database using environment variables
    kubectl exec -n postgresql deployment/postgresql -- env PGPASSWORD="$POSTGRES_PASSWORD" psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE $MLFLOW_DB_NAME;" 2>/dev/null || true
    
    print_success "MLflow database created (or already exists)"
}

# Function to create MLflow bucket in MinIO
create_mlflow_bucket() {
    print_status "Creating MLflow bucket in MinIO..."
    
    # Wait for MinIO to be ready
    kubectl wait --for=condition=ready pod -l app=minio -n minio --timeout=300s
    
    # Create MLflow bucket using environment variables
    kubectl exec -n minio deployment/minio -- mc mb minio/$MLFLOW_S3_BUCKET 2>/dev/null || true
    
    print_success "MLflow bucket created (or already exists)"
}

# Function to install MLflow
install_mlflow() {
    print_status "Installing MLflow..."
    
    # Add community charts repository if not exists
    if ! helm repo list | grep -q "community-charts"; then
        print_status "Adding community-charts repository..."
        helm repo add community-charts https://community-charts.github.io/helm-charts
        helm repo update
    fi
    
    # Create namespace if not exists
    if ! namespace_exists; then
        print_status "Creating namespace $NAMESPACE..."
        kubectl create namespace "$NAMESPACE"
    fi
    
    # Create MLflow database and bucket
    create_mlflow_database
    create_mlflow_bucket
    
    # Prepare values file with environment variable substitution
    local temp_values=$(mktemp)
    LOCAL_DOMAIN="$LOCAL_DOMAIN" \
    POSTGRES_USER="$POSTGRES_USER" \
    POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    MLFLOW_DB_NAME="$MLFLOW_DB_NAME" \
    MINIO_ADMIN="$MINIO_ADMIN" \
    MINIO_ADMIN_PASSWORD="$MINIO_ADMIN_PASSWORD" \
    MLFLOW_S3_BUCKET="$MLFLOW_S3_BUCKET" \
    MLFLOW_S3_ENDPOINT_URL="$MLFLOW_S3_ENDPOINT_URL" \
    MLFLOW_S3_IGNORE_TLS="$MLFLOW_S3_IGNORE_TLS" \
    MLFLOW_AWS_REGION="$MLFLOW_AWS_REGION" \
    envsubst < extensions/mlflow/values.yaml > "$temp_values"
    
    # Install MLflow
    print_status "Installing MLflow Helm chart..."
    helm install "$RELEASE_NAME" "$CHART_NAME" \
        --namespace "$NAMESPACE" \
        --values "$temp_values"
    
    # Cleanup temp file
    rm -f "$temp_values"
    
    print_success "MLflow installed successfully!"
    print_status "Access URL: https://mlflow.$LOCAL_DOMAIN"
    print_status "Wait a few minutes for the service to be ready..."
}

# Function to upgrade MLflow
upgrade_mlflow() {
    print_status "Upgrading MLflow..."
    
    if ! release_exists; then
        print_error "MLflow is not installed. Run install first."
        exit 1
    fi
    
    # Update helm repositories
    helm repo update
    
    # Prepare values file with environment variable substitution
    local temp_values=$(mktemp)
    LOCAL_DOMAIN="$LOCAL_DOMAIN" \
    POSTGRES_USER="$POSTGRES_USER" \
    POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    MLFLOW_DB_NAME="$MLFLOW_DB_NAME" \
    MINIO_ADMIN="$MINIO_ADMIN" \
    MINIO_ADMIN_PASSWORD="$MINIO_ADMIN_PASSWORD" \
    MLFLOW_S3_BUCKET="$MLFLOW_S3_BUCKET" \
    MLFLOW_S3_ENDPOINT_URL="$MLFLOW_S3_ENDPOINT_URL" \
    MLFLOW_S3_IGNORE_TLS="$MLFLOW_S3_IGNORE_TLS" \
    MLFLOW_AWS_REGION="$MLFLOW_AWS_REGION" \
    envsubst < extensions/mlflow/values.yaml > "$temp_values"
    
    # Upgrade MLflow
    helm upgrade "$RELEASE_NAME" "$CHART_NAME" \
        --namespace "$NAMESPACE" \
        --values "$temp_values"
    
    # Cleanup temp file
    rm -f "$temp_values"
    
    print_success "MLflow upgraded successfully!"
}

# Function to uninstall MLflow
uninstall_mlflow() {
    print_status "Uninstalling MLflow..."
    
    if release_exists; then
        helm uninstall "$RELEASE_NAME" --namespace "$NAMESPACE"
        print_success "MLflow uninstalled successfully!"
    else
        print_warning "MLflow is not installed."
    fi
    
    # Delete namespace if exists
    if namespace_exists; then
        print_status "Deleting namespace $NAMESPACE..."
        kubectl delete namespace "$NAMESPACE"
        print_success "Namespace $NAMESPACE deleted!"
    fi
}

# Function to show MLflow status
show_status() {
    print_status "MLflow Status:"
    echo
    
    if ! namespace_exists; then
        print_warning "Namespace $NAMESPACE does not exist."
        return
    fi
    
    if ! release_exists; then
        print_warning "MLflow is not installed in namespace $NAMESPACE."
        return
    fi
    
    echo "Helm Release:"
    helm list -n "$NAMESPACE" | grep "$RELEASE_NAME"
    echo
    
    echo "Pods:"
    kubectl get pods -n "$NAMESPACE"
    echo
    
    echo "Services:"
    kubectl get services -n "$NAMESPACE"
    echo
    
    echo "Ingress:"
    kubectl get ingress -n "$NAMESPACE"
    echo
    
    echo "Access URL: https://mlflow.$LOCAL_DOMAIN"
}

# Function to show MLflow logs
show_logs() {
    print_status "MLflow Logs:"
    
    if ! namespace_exists; then
        print_error "Namespace $NAMESPACE does not exist."
        exit 1
    fi
    
    if ! release_exists; then
        print_error "MLflow is not installed."
        exit 1
    fi
    
    # Get pod name
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=mlflow -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$POD_NAME" ]; then
        print_error "No MLflow pods found."
        exit 1
    fi
    
    kubectl logs -n "$NAMESPACE" "$POD_NAME" -f
}

# Main script logic
case "${1:-help}" in
    install)
        install_mlflow
        ;;
    upgrade)
        upgrade_mlflow
        ;;
    uninstall)
        uninstall_mlflow
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    help|*)
        echo "MLflow Management Script"
        echo "Usage: $0 [install|upgrade|uninstall|status|logs]"
        echo ""
        echo "Commands:"
        echo "  install   - Install MLflow"
        echo "  upgrade   - Upgrade MLflow"
        echo "  uninstall - Uninstall MLflow"
        echo "  status    - Show MLflow status"
        echo "  logs      - Show MLflow logs"
        echo ""
        echo "Environment variables:"
        echo "  LOCAL_DOMAIN - Local domain (default: beavers.dev)"
        ;;
esac 