#!/bin/bash

# Script to manage ArgoCD GitOps platform
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

# Function to check if ArgoCD values file exists
check_values_file() {
    if [ ! -f "extensions/argocd/values.yaml" ]; then
        log_error "ArgoCD values file not found: extensions/argocd/values.yaml"
        exit 1
    fi
}

# Function to install ArgoCD
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

# Function to update ArgoCD
update_argocd() {
    log_info "Updating ArgoCD..."
    
    # Update Helm repositories
    helm repo update
    
    # Prepare values file with domain substitution
    local values_file="extensions/argocd/values.yaml"
    local temp_values=$(mktemp)
    sed "s/\${LOCAL_DOMAIN}/$LOCAL_DOMAIN/g" "$values_file" > "$temp_values"
    
    # Update ArgoCD
    helm upgrade argocd argo/argo-cd \
        --namespace argocd \
        -f "$temp_values" \
        --wait
    
    # Cleanup temp file
    rm -f "$temp_values"
    
    log_success "ArgoCD updated successfully!"
    echo ""
    echo "Access ArgoCD at: https://argo.$LOCAL_DOMAIN"
}

# Function to uninstall ArgoCD
uninstall_argocd() {
    log_warning "This will completely remove ArgoCD and all its data!"
    echo -n "Are you sure you want to continue? (y/N): "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "Uninstalling ArgoCD..."
        
        # Uninstall ArgoCD
        helm uninstall argocd -n argocd
        
        # Remove namespace if it exists
        if kubectl get namespace argocd >/dev/null 2>&1; then
            kubectl delete namespace argocd
        fi
        
        log_success "ArgoCD uninstalled successfully!"
    else
        log_info "Uninstall cancelled."
    fi
}

# Function to show ArgoCD status
status_argocd() {
    log_info "Checking ArgoCD status..."
    
    if ! kubectl get namespace argocd >/dev/null 2>&1; then
        log_warning "ArgoCD namespace not found. ArgoCD is not installed."
        return
    fi
    
    echo ""
    echo "ArgoCD Pods:"
    kubectl get pods -n argocd
    
    echo ""
    echo "ArgoCD Services:"
    kubectl get svc -n argocd
    
    echo ""
    echo "ArgoCD Ingress:"
    kubectl get ingress -n argocd 2>/dev/null || echo "No ingress found"
    
    echo ""
    echo "Access ArgoCD at: https://argo.$LOCAL_DOMAIN"
}

# Function to show help
show_help() {
    echo "Usage: $0 {install|update|uninstall|status|help}"
    echo ""
    echo "Commands:"
    echo "  install   - Install ArgoCD GitOps platform"
    echo "  update    - Update ArgoCD to latest version"
    echo "  uninstall - Remove ArgoCD completely"
    echo "  status    - Show ArgoCD status and access info"
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
            install_argocd
            ;;
        update)
            check_cluster
            check_values_file
            update_argocd
            ;;
        uninstall)
            check_cluster
            uninstall_argocd
            ;;
        status)
            check_cluster
            status_argocd
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