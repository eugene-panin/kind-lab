#!/bin/bash

# Script to install ArgoCD GitOps platform
# This script installs ArgoCD with basic configuration for local development

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

install_argocd() {
    log_info "Installing ArgoCD..."
    
    # Add ArgoCD Helm repository
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    
    # Prepare values file with domain substitution
    local values_file="extensions/argocd/values.yaml"
    local temp_values=$(mktemp)
    sed "s/\${LOCAL_DOMAIN}/$LOCAL_DOMAIN/g" "$values_file" > "$temp_values"
    
    # Install ArgoCD
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --create-namespace \
        -f "$temp_values" \
        --wait
    
    # Cleanup temp file
    rm -f "$temp_values"
    
    # Get admin password
    local admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    log_success "ArgoCD installed successfully!"
    echo ""
    echo "Access ArgoCD at: https://argo.$LOCAL_DOMAIN"
    echo "Username: admin"
    echo "Password: $admin_password"
    echo ""
    echo "To get the password later, run:"
    echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    echo ""
    echo "To access ArgoCD CLI:"
    echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "argocd login localhost:8080"
}

# Main script logic
main() {
    # Check if cluster is running
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Kubernetes cluster is not accessible. Please start the cluster first."
        exit 1
    fi
    
    # Check if ArgoCD values file exists
    if [ ! -f "extensions/argocd/values.yaml" ]; then
        log_error "ArgoCD values file not found: extensions/argocd/values.yaml"
        exit 1
    fi
    
    # Install ArgoCD
    install_argocd
}

# Run main function
main "$@" 