#!/bin/bash

# Script to manage PostgreSQL
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

NAMESPACE="postgresql"
CHART_NAME="postgresql"
REPO_NAME="bitnami"
CHART_VERSION="16.7.14"
VALUES_FILE="extensions/postgresql/values.yaml"

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
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres123}
POSTGRES_DB=${POSTGRES_DB:-lab}

# Function to check if cluster is accessible
check_cluster() {
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Kubernetes cluster is not accessible. Please start the cluster first."
        exit 1
    fi
}

# Function to check if PostgreSQL values file exists
check_values_file() {
    if [ ! -f "extensions/postgresql/values.yaml" ]; then
        log_error "PostgreSQL values file not found: extensions/postgresql/values.yaml"
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

# Function to install PostgreSQL
install() {
    log_info "Installing PostgreSQL..."
    
    # Проверка: если релиз уже существует, не устанавливать повторно
    if release_exists "$NAMESPACE" "$CHART_NAME"; then
        log_warning "PostgreSQL is already installed in namespace $NAMESPACE. Use 'upgrade' to update or 'uninstall' to remove."
        return 0
    fi
    
    # Create namespace if it doesn't exist
    if ! namespace_exists "$NAMESPACE"; then
        log_info "Creating namespace $NAMESPACE..."
        kubectl create namespace "$NAMESPACE"
    fi
    
    # Copy TLS certificate to namespace
    copy_tls_certificate "$NAMESPACE"
    
    # Add Bitnami repository if not already added
    if ! helm repo list | grep -q "$REPO_NAME"; then
        log_info "Adding Bitnami repository..."
        helm repo add "$REPO_NAME" https://charts.bitnami.com/bitnami
        helm repo update
    fi
    
    # Check if values file exists
    local values_file="extensions/postgresql/values.yaml"
    if [ ! -f "$values_file" ]; then
        log_warning "Values file not found: $values_file"
        log_info "Installing with default values..."
        helm install "$CHART_NAME" "$REPO_NAME/postgresql" \
            --namespace "$NAMESPACE" \
            --create-namespace \
            --wait \
            --timeout 10m
    else
        log_info "Installing with custom values from: $values_file"
        # Prepare values file with environment variable substitution
        local temp_values=$(mktemp)
        LOCAL_DOMAIN="$LOCAL_DOMAIN" \
        POSTGRES_USER="$POSTGRES_USER" \
        POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
        POSTGRES_DB="$POSTGRES_DB" \
        envsubst < "$values_file" > "$temp_values"
        
        helm install "$CHART_NAME" "$REPO_NAME/postgresql" \
            --namespace "$NAMESPACE" \
            --create-namespace \
            --values "$temp_values" \
            --wait \
            --timeout 10m
        
        # Cleanup temp file
        rm -f "$temp_values"
    fi
    
    log_success "PostgreSQL installed successfully!"
    log_info "PostgreSQL will be available at: postgresql.$NAMESPACE.svc.cluster.local:5432"
    log_info "Database: $POSTGRES_DB"
    log_info "User: $POSTGRES_USER"
    log_info "Password: $POSTGRES_PASSWORD"
}

# Function to upgrade PostgreSQL
upgrade() {
    log_info "Upgrading PostgreSQL..."
    
    # Проверка: если релиз не установлен, не выполнять upgrade
    if ! release_exists "$NAMESPACE" "$CHART_NAME"; then
        log_warning "PostgreSQL is not installed in namespace $NAMESPACE. Use 'install' to deploy."
        return 0
    fi
    
    # Copy TLS certificate to namespace (in case it was deleted)
    copy_tls_certificate "$NAMESPACE"
    
    # Update repository
    helm repo update
    
    # Prepare values file with environment variable substitution
    local temp_values=$(mktemp)
    LOCAL_DOMAIN="$LOCAL_DOMAIN" \
    POSTGRES_USER="$POSTGRES_USER" \
    POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    POSTGRES_DB="$POSTGRES_DB" \
    envsubst < "$VALUES_FILE" > "$temp_values"
    
    # Upgrade PostgreSQL
    helm upgrade "$CHART_NAME" "$REPO_NAME/postgresql" \
        --namespace "$NAMESPACE" \
        --version "$CHART_VERSION" \
        --values "$temp_values" \
        --wait \
        --timeout 10m
    
    # Cleanup temp file
    rm -f "$temp_values"
    
    log_success "PostgreSQL upgraded successfully!"
}

# Function to uninstall PostgreSQL
uninstall() {
    log_info "Uninstalling PostgreSQL..."
    
    if ! release_exists "$NAMESPACE" "$CHART_NAME"; then
        log_warning "PostgreSQL is not installed."
        return 0
    fi
    
    # Uninstall PostgreSQL
    helm uninstall "$CHART_NAME" --namespace "$NAMESPACE"
    
    # Delete namespace if it exists
    if namespace_exists "$NAMESPACE"; then
        log_info "Deleting namespace $NAMESPACE..."
        kubectl delete namespace "$NAMESPACE"
    fi
    
    log_success "PostgreSQL uninstalled successfully!"
}

# Function to show status
status() {
    log_info "Checking PostgreSQL status..."
    
    if ! release_exists "$NAMESPACE" "$CHART_NAME"; then
        log_warning "PostgreSQL is not installed."
        return 0
    fi
    
    echo
    log_info "PostgreSQL Release Status:"
    helm list -n "$NAMESPACE" | grep "$CHART_NAME"
    
    echo
    log_info "PostgreSQL Pods:"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=postgresql
    
    echo
    log_info "PostgreSQL Services:"
    kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=postgresql
    
    echo
    log_info "TLS Certificate:"
    kubectl get secret local-dev-tls -n "$NAMESPACE" 2>/dev/null || log_warning "TLS certificate not found in namespace"
    
    echo
    log_info "Connection Details:"
    log_info "  Host: postgresql.$NAMESPACE.svc.cluster.local"
    log_info "  Port: 5432"
    log_info "  Database: $POSTGRES_DB"
    log_info "  User: $POSTGRES_USER"
    log_info "  Password: $POSTGRES_PASSWORD"
}

# Function to show logs
logs() {
    if ! release_exists "$NAMESPACE" "$CHART_NAME"; then
        log_error "PostgreSQL is not installed."
        exit 1
    fi
    
    log_info "Showing PostgreSQL logs..."
    kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/name=postgresql --tail=100 -f
}

# Function to show help
show_help() {
    echo "Usage: $0 {install|upgrade|uninstall|status|logs|help}"
    echo
    echo "Commands:"
    echo "  install   - Install PostgreSQL"
    echo "  upgrade   - Upgrade PostgreSQL"
    echo "  uninstall - Uninstall PostgreSQL"
    echo "  status    - Show PostgreSQL status"
    echo "  logs      - Show PostgreSQL logs"
    echo "  help      - Show this help message"
    echo
    echo "PostgreSQL will be installed with:"
    echo "  - Database: $POSTGRES_DB"
    echo "  - User: $POSTGRES_USER"
    echo "  - Password: $POSTGRES_PASSWORD"
    echo "  - TLS certificate automatically copied to namespace"
    echo
    echo "Environment variables (from .env file):"
    echo "  LOCAL_DOMAIN - Local domain (default: beavers.dev)"
    echo "  POSTGRES_USER - Database user (default: postgres)"
    echo "  POSTGRES_PASSWORD - Database password"
    echo "  POSTGRES_DB - Database name (default: lab)"
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