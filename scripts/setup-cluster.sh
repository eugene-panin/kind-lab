#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Variables and Constants ---
# Kind cluster name
CLUSTER_NAME=${CLUSTER_NAME:-"kind-lab"}
# Flag to indicate if the cluster should be recreated
RECREATE=${RECREATE:-"true"}
# Local domain
LOCAL_DOMAIN=${LOCAL_DOMAIN:-"local.dev"}
# Path to the certificates directory
CERTS_DIR="$(pwd)/certs"
# Paths to certificate files
CERT_FILE="$CERTS_DIR/cert.pem"
KEY_FILE="$CERTS_DIR/key.pem"
# Path to Kind configuration
KIND_CONFIG_PATH="k8s/kind-config.yaml"
# Path to the application manifest
APP_MANIFEST_PATH="k8s/status-app.yaml"

# --- Log Colors ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Logging Functions ---
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# --- Functions ---
check_prerequisites() {
    log_info "Checking for certificates..."
    if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
        log_error "Certificate files not found in '$CERTS_DIR'."
        log_warning "Please configure the domain first by running: make configure-domain"
        exit 1
    fi
    log_success "Certificates found."
}

# Function to prepare Kind configuration with sed substitution
prepare_kind_config() {
    log_info "Preparing Kind configuration..."
    
    # Get absolute path to src directory
    local src_path="$(pwd)/src"
    
    # Check if config exists
    if [ ! -f "$KIND_CONFIG_PATH" ]; then
        log_error "Kind configuration not found: $KIND_CONFIG_PATH"
        exit 1
    fi
    
    # Create temporary config with absolute path and cluster name
    local temp_config=$(mktemp)
    sed -e "s|__SRC_PATH__|$src_path|g" \
        -e "s|__CLUSTER_NAME__|$CLUSTER_NAME|g" \
        "$KIND_CONFIG_PATH" > "$temp_config"
    
    # Use temporary config for cluster creation
    KIND_CONFIG_TEMP="$temp_config"
    log_success "Kind configuration prepared with path: $src_path and cluster name: $CLUSTER_NAME"
}

# Function to check if the cluster exists
cluster_exists() {
    kind get clusters | grep -q "^$CLUSTER_NAME$"
}

# Function to delete the cluster
delete_cluster() {
    log_warning "Deleting existing cluster '$CLUSTER_NAME'..."
    kind delete cluster --name "$CLUSTER_NAME"
    log_success "Cluster '$CLUSTER_NAME' deleted."
}

# Function to create the cluster
create_cluster() {
    log_info "Creating Kind cluster '$CLUSTER_NAME'..."
    kind create cluster --config "$KIND_CONFIG_TEMP" --wait 300s
    log_success "Cluster '$CLUSTER_NAME' created successfully."
}

# Function to install Nginx Ingress Controller
install_ingress_controller() {
    log_info "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    log_info "Waiting for Ingress Controller to be ready..."
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s
    log_success "NGINX Ingress Controller installed."
}

# Separate function for creating the secret
setup_tls_secrets_in_k8s() {
    log_info "Creating/updating TLS secrets in the cluster..."
    kubectl delete secret local-dev-tls --ignore-not-found=true
    kubectl create secret tls local-dev-tls --cert="$CERT_FILE" --key="$KEY_FILE"
    log_success "TLS secrets created/updated successfully."
}

# Function to deploy the application
deploy_app() {
    log_info "Preparing and deploying the status page..."

    # 1. Generate index.html from template
    local html_template_path="src/status-app/index.html"
    
    # Read the template
    local template_content
    template_content=$(cat "$html_template_path")

    # Replace placeholders
    template_content="${template_content//\{\{CLUSTER_NAME\}\}/$CLUSTER_NAME}"
    template_content="${template_content//\{\{LOCAL_DOMAIN\}\}/$LOCAL_DOMAIN}"
    template_content="${template_content//\{\{DEPLOY_TIME\}\}/$(date -uR)}"
    
    # Write the result back to the source file for live-reloading
    echo "$template_content" > "$html_template_path"
    log_info "'index.html' file has been updated with deployment data."

    # 2. Deploy Kubernetes resources
    local temp_manifest=$(mktemp)
    sed "s|\${LOCAL_DOMAIN}|${LOCAL_DOMAIN}|g" "$APP_MANIFEST_PATH" > "$temp_manifest"
    kubectl apply -f "$temp_manifest"
    rm "$temp_manifest"
    
    log_info "Forcing pod restart to apply changes..."
    kubectl patch deployment status-app -p \
      "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"restarted-at\":\"$(date +%s)\"}}}}}"
    log_success "Status page deployed successfully."
}

# Function to cleanup temporary files
cleanup() {
    if [ -n "$KIND_CONFIG_TEMP" ] && [ -f "$KIND_CONFIG_TEMP" ]; then
        rm -f "$KIND_CONFIG_TEMP"
    fi
}

# Function to cleanup dangling kind containers and networks
docker_cleanup_kind() {
    log_info "Cleaning up dangling Docker containers and networks for kind..."
    # Удалить все контейнеры с именем kind-lab-*
    local containers=$(docker ps -a --filter "name=${CLUSTER_NAME}-" --format "{{.ID}}")
    if [ -n "$containers" ]; then
        docker rm -f $containers && log_success "Removed containers: $containers"
    fi
    # Удалить сеть kind, если осталась
    if docker network ls | grep -q " kind[[:space:]]"; then
        docker network rm kind && log_success "Removed docker network: kind"
    fi
}

# Main script logic
main() {
    log_info "🚀 Starting cluster management script..."
    log_info "Using domain (from .env): *.$LOCAL_DOMAIN"

    check_prerequisites
    prepare_kind_config

    # Set trap to cleanup on exit
    trap cleanup EXIT

    if cluster_exists && [ "$RECREATE" = "true" ]; then
        delete_cluster
        docker_cleanup_kind
    elif ! cluster_exists; then
        docker_cleanup_kind
    fi

    if ! cluster_exists; then
        create_cluster
        install_ingress_controller
    fi

    setup_tls_secrets_in_k8s
    deploy_app
    
    print_summary
}

# --- Utilities ---
# Function to print the summary
print_summary() {
    log_info "🎉 All done!"
    echo -e "${GREEN}===============================================================${NC}"
    echo -e "  Cluster '${CLUSTER_NAME}' is up and running."
    echo -e "  The status page is available at:"
    echo -e "    - ${YELLOW}https://status.${LOCAL_DOMAIN}${NC}"
    echo -e "${GREEN}===============================================================${NC}"
}

# Run main function
main
