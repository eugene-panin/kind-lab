#!/bin/bash

# Script to manage ArgoCD
# Supports: install, update, uninstall, status operations

set -e

# Load environment variables from .env file
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Path to certificates
CERTS_DIR="$(pwd)/certs"
CERT_FILE="$CERTS_DIR/cert.pem"
KEY_FILE="$CERTS_DIR/key.pem"

NAMESPACE="argocd"
CHART_NAME="argocd"
REPO_NAME="argo"
CHART_VERSION="8.1.2"
VALUES_FILE="extensions/argocd/values.yaml"

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

# Get environment variables with defaults
LOCAL_DOMAIN=${LOCAL_DOMAIN:-beavers.dev}
ARGO_ADMIN=${ARGO_ADMIN:-admin}
ARGO_ADMIN_PASSWORD=${ARGO_ADMIN_PASSWORD:-admin123}

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

# Function to check if namespace exists
namespace_exists() {
    kubectl get namespace "$1" >/dev/null 2>&1
}

# Function to check if release exists
release_exists() {
    helm list -n "$1" | grep -q "$2"
}

# Function to copy TLS certificate to namespace
copy_tls_certificate() {
    local namespace="$1"
    log_info "Copying TLS certificate to namespace $namespace..."
    
    # Always delete and recreate the secret to ensure it is up-to-date
    kubectl delete secret local-dev-tls -n "$namespace" --ignore-not-found
    
    # Create TLS secret
    kubectl create secret tls local-dev-tls \
        --cert="$CERT_FILE" \
        --key="$KEY_FILE" \
        -n "$namespace"
    
    # Set as default TLS secret for ingress
    kubectl patch namespace "$namespace" -p '{"metadata":{"annotations":{"cert-manager.io/default-issuer":"local-dev-tls"}}}' 2>/dev/null || true
    
    log_success "TLS certificate applied successfully to namespace $namespace"
}

# Function to install ArgoCD
install() {
    log_info "Installing ArgoCD..."
    
    # Проверка: если релиз уже существует, не устанавливать повторно
    if release_exists "$NAMESPACE" "$CHART_NAME"; then
        log_warning "ArgoCD is already installed in namespace $NAMESPACE. Use 'upgrade' to update or 'uninstall' to remove."
        return 0
    fi
    
    # Create namespace if it doesn't exist
    if ! namespace_exists "$NAMESPACE"; then
        log_info "Creating namespace $NAMESPACE..."
        kubectl create namespace "$NAMESPACE"
    fi
    
    # Copy TLS certificate to namespace
    copy_tls_certificate "$NAMESPACE"
    
    # Add ArgoCD repository if not already added
    if ! helm repo list | grep -q "$REPO_NAME"; then
        log_info "Adding ArgoCD repository..."
        helm repo add "$REPO_NAME" https://argoproj.github.io/argo-helm
        helm repo update
    fi
    
    # Check if values file exists
    local values_file="extensions/argocd/values.yaml"
    if [ ! -f "$values_file" ]; then
        log_warning "Values file not found: $values_file"
        log_info "Installing with default values..."
        helm install "$CHART_NAME" "$REPO_NAME/argo-cd" \
            --namespace "$NAMESPACE" \
            --create-namespace \
            --wait \
            --timeout 10m
    else
        log_info "Installing with custom values from: $values_file"
        # Prepare values file with environment variable substitution
        local temp_values=$(mktemp)
        LOCAL_DOMAIN="$LOCAL_DOMAIN" \
        ARGO_ADMIN="$ARGO_ADMIN" \
        ARGO_ADMIN_PASSWORD="$ARGO_ADMIN_PASSWORD" \
        envsubst < "$values_file" > "$temp_values"
        
        helm install "$CHART_NAME" "$REPO_NAME/argo-cd" \
            --namespace "$NAMESPACE" \
            --create-namespace \
            --values "$temp_values" \
            --wait \
            --timeout 10m
        
        # Cleanup temp file
        rm -f "$temp_values"
    fi
    
    log_success "ArgoCD installed successfully!"
    log_info "ArgoCD will be available at: https://argo.$LOCAL_DOMAIN"
    log_info "Admin credentials: $ARGO_ADMIN / $ARGO_ADMIN_PASSWORD"
}

# Function to upgrade ArgoCD
upgrade() {
    log_info "Upgrading ArgoCD..."
    
    # Проверка: если релиз не установлен, не выполнять upgrade
    if ! release_exists "$NAMESPACE" "$CHART_NAME"; then
        log_warning "ArgoCD is not installed in namespace $NAMESPACE. Use 'install' to deploy."
        return 0
    fi
    
    # Copy TLS certificate to namespace (in case it was deleted)
    copy_tls_certificate "$NAMESPACE"
    
    # Update repository
    helm repo update
    
    # Prepare values file with environment variable substitution
    local temp_values=$(mktemp)
    LOCAL_DOMAIN="$LOCAL_DOMAIN" \
    ARGO_ADMIN="$ARGO_ADMIN" \
    ARGO_ADMIN_PASSWORD="$ARGO_ADMIN_PASSWORD" \
    envsubst < "$VALUES_FILE" > "$temp_values"
    
    # Upgrade ArgoCD
    helm upgrade "$CHART_NAME" "$REPO_NAME/argo-cd" \
        --namespace "$NAMESPACE" \
        --version "$CHART_VERSION" \
        --values "$temp_values" \
        --wait \
        --timeout 10m
    
    # Cleanup temp file
    rm -f "$temp_values"
    
    log_success "ArgoCD upgraded successfully!"
}

# Function to uninstall ArgoCD
uninstall() {
    log_info "Uninstalling ArgoCD..."
    
    if ! release_exists "$NAMESPACE" "$CHART_NAME"; then
        log_warning "ArgoCD is not installed."
        return 0
    fi
    
    # Uninstall ArgoCD
    helm uninstall "$CHART_NAME" --namespace "$NAMESPACE"
    
    # Delete namespace if it exists
    if namespace_exists "$NAMESPACE"; then
        log_info "Deleting namespace $NAMESPACE..."
        kubectl delete namespace "$NAMESPACE"
    fi
    
    log_success "ArgoCD uninstalled successfully!"
}

# Function to show status
status() {
    log_info "Checking ArgoCD status..."
    
    if ! release_exists "$NAMESPACE" "$CHART_NAME"; then
        log_warning "ArgoCD is not installed."
        return 0
    fi
    
    echo
    log_info "ArgoCD Release Status:"
    helm list -n "$NAMESPACE" | grep "$CHART_NAME"
    
    echo
    log_info "ArgoCD Pods:"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=argocd-server
    
    echo
    log_info "ArgoCD Services:"
    kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=argocd-server
    
    echo
    log_info "ArgoCD Ingress:"
    kubectl get ingress -n "$NAMESPACE" -l app.kubernetes.io/name=argocd-server
    
    echo
    log_info "TLS Certificate:"
    kubectl get secret local-dev-tls -n "$NAMESPACE" 2>/dev/null || log_warning "TLS certificate not found in namespace"
    
    echo
    log_info "Access URL: https://argo.$LOCAL_DOMAIN"
    log_info "Admin credentials: $ARGO_ADMIN / $ARGO_ADMIN_PASSWORD"
}

# Function to show logs
logs() {
    if ! release_exists "$NAMESPACE" "$CHART_NAME"; then
        log_error "ArgoCD is not installed."
        exit 1
    fi
    
    log_info "Showing ArgoCD logs..."
    kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/name=argocd-server --tail=100 -f
}

# Function to show help
show_help() {
    echo "Usage: $0 {install|upgrade|uninstall|status|logs|help}"
    echo
    echo "Commands:"
    echo "  install   - Install ArgoCD"
    echo "  upgrade   - Upgrade ArgoCD"
    echo "  uninstall - Uninstall ArgoCD"
    echo "  status    - Show ArgoCD status"
    echo "  logs      - Show ArgoCD logs"
    echo "  help      - Show this help message"
    echo
    echo "ArgoCD will be installed with:"
    echo "  - Web UI at https://argo.$LOCAL_DOMAIN"
    echo "  - Admin: $ARGO_ADMIN / $ARGO_ADMIN_PASSWORD"
    echo "  - TLS certificate automatically copied to namespace"
    echo
    echo "Environment variables (from .env file):"
    echo "  LOCAL_DOMAIN - Local domain (default: beavers.dev)"
    echo "  ARGO_ADMIN - Admin username (default: admin)"
    echo "  ARGO_ADMIN_PASSWORD - Admin password"
}

# Main script logic
case "${1:-help}" in
    install)
        check_cluster
        check_values_file "$VALUES_FILE"
        install
        ;;
    upgrade)
        check_cluster
        check_values_file "$VALUES_FILE"
        upgrade
        ;;
    uninstall)
        check_cluster
        uninstall
        ;;
    status)
        check_cluster
        status
        ;;
    logs)
        check_cluster
        logs
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac 