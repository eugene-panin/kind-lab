#!/bin/bash

# Script to manage JupyterHub
# Supports: install, update, uninstall operations

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

# Function to log warning
log_warning() {
    print_color $YELLOW "⚠️  $1"
}

# Function to log error
log_error() {
    print_color $RED "❌ $1"
}

# Get environment variables
LOCAL_DOMAIN=${LOCAL_DOMAIN:-beavers.dev}

# Function to check if cluster is accessible
check_cluster() {
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Kubernetes cluster is not accessible. Please start the cluster first."
        exit 1
    fi
}

# Function to check if JupyterHub values file exists
check_values_file() {
    if [ ! -f "extensions/jupyterhub/values.yaml" ]; then
        log_error "JupyterHub values file not found: extensions/jupyterhub/values.yaml"
        exit 1
    fi
}

# Function to install JupyterHub
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

# Function to update JupyterHub
update_jupyterhub() {
    log_info "Updating JupyterHub..."
    
    # Update Helm repositories
    helm repo update
    
    # Prepare values file with domain substitution
    local values_file="extensions/jupyterhub/values.yaml"
    local temp_values=$(mktemp)
    sed "s/\${LOCAL_DOMAIN}/$LOCAL_DOMAIN/g" "$values_file" > "$temp_values"
    
    # Update JupyterHub
    helm upgrade jupyterhub jupyterhub/jupyterhub \
        --namespace jupyterhub \
        -f "$temp_values" \
        --set proxy.secretToken=dev-jupyterhub-token \
        --wait
    
    # Cleanup temp file
    rm -f "$temp_values"
    
    log_success "JupyterHub updated successfully!"
    echo ""
    echo "Access JupyterHub at: https://jupyter.$LOCAL_DOMAIN"
}

# Function to uninstall JupyterHub
uninstall_jupyterhub() {
    log_warning "This will completely remove JupyterHub and all user data!"
    echo -n "Are you sure you want to continue? (y/N): "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "Uninstalling JupyterHub..."
        
        # Uninstall JupyterHub
        helm uninstall jupyterhub -n jupyterhub
        
        # Remove namespace if it exists
        if kubectl get namespace jupyterhub >/dev/null 2>&1; then
            kubectl delete namespace jupyterhub
        fi
        
        log_success "JupyterHub uninstalled successfully!"
    else
        log_info "Uninstall cancelled."
    fi
}

# Function to show JupyterHub status
status_jupyterhub() {
    log_info "Checking JupyterHub status..."
    
    if ! kubectl get namespace jupyterhub >/dev/null 2>&1; then
        log_warning "JupyterHub namespace not found. JupyterHub is not installed."
        return
    fi
    
    echo ""
    echo "JupyterHub Pods:"
    kubectl get pods -n jupyterhub
    
    echo ""
    echo "JupyterHub Services:"
    kubectl get svc -n jupyterhub
    
    echo ""
    echo "JupyterHub Ingress:"
    kubectl get ingress -n jupyterhub 2>/dev/null || echo "No ingress found"
    
    echo ""
    echo "Access JupyterHub at: https://jupyter.$LOCAL_DOMAIN"
    echo "Default user: dummy"
    echo "Password: dummy"
}

# Function to show help
show_help() {
    echo "Usage: $0 {install|update|uninstall|status|help}"
    echo ""
    echo "Commands:"
    echo "  install   - Install JupyterHub"
    echo "  update    - Update JupyterHub to latest version"
    echo "  uninstall - Remove JupyterHub completely"
    echo "  status    - Show JupyterHub status and access info"
    echo "  help      - Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  LOCAL_DOMAIN - Local domain (default: beavers.dev)"
}

# Main script logic
main() {
    local action=${1:-help}
    
    case $action in
        install)
            check_cluster
            check_values_file
            install_jupyterhub
            ;;
        update)
            check_cluster
            check_values_file
            update_jupyterhub
            ;;
        uninstall)
            check_cluster
            uninstall_jupyterhub
            ;;
        status)
            check_cluster
            status_jupyterhub
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown action: $action"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 