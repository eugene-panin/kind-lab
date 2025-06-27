#!/bin/bash

# Script to install JupyterHub
# This script installs JupyterHub with basic configuration for local development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function for colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to log info
log_info() {
    print_color $BLUE "ℹ️  $1"
}

# Function to log success
log_success() {
    print_color $GREEN "✅ $1"
}

# Function to log error
log_error() {
    print_color $RED "❌ $1"
}

# Get environment variables
LOCAL_DOMAIN=${LOCAL_DOMAIN:-beavers.dev}

install_jupyterhub() {
    log_info "Installing JupyterHub..."
    
    # Add JupyterHub Helm repository
    helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
    helm repo update
    
    # Prepare values file with domain substitution
    local values_file="extensions/jupyterhub/values.yaml"
    local temp_values=$(mktemp)
    sed "s/\${LOCAL_DOMAIN}/$LOCAL_DOMAIN/g" "$values_file" > "$temp_values"
    
    # Install JupyterHub
    helm upgrade --install jupyterhub jupyterhub/jupyterhub \
        --namespace jupyterhub \
        --create-namespace \
        -f "$temp_values" \
        --set proxy.secretToken=dev-jupyterhub-token \
        --wait
    
    # Cleanup temp file
    rm -f "$temp_values"
    
    log_success "JupyterHub installed successfully!"
    echo ""
    echo "Access JupyterHub at: https://jupyter.$LOCAL_DOMAIN"
    echo ""
    echo "Default user: dummy"
    echo "Password: dummy"
    echo ""
    echo "To check JupyterHub status:"
    echo "kubectl get pods -n jupyterhub"
    echo ""
    echo "To check ingress configuration:"
    echo "kubectl get ingress -n jupyterhub"
}

# Main script logic
main() {
    # Check if cluster is running
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Kubernetes cluster is not accessible. Please start the cluster first."
        exit 1
    fi
    
    # Check if JupyterHub values file exists
    if [ ! -f "extensions/jupyterhub/values.yaml" ]; then
        log_error "JupyterHub values file not found: extensions/jupyterhub/values.yaml"
        exit 1
    fi
    
    # Install JupyterHub
    install_jupyterhub
}

# Run main function
main "$@" 