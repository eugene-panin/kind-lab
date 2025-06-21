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
    kind create cluster --config "$KIND_CONFIG_PATH" --wait 300s
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

# Main script logic
main() {
    log_info "🚀 Starting cluster management script..."
    log_info "Using domain (from .env): *.$LOCAL_DOMAIN"

    check_prerequisites

    if cluster_exists && [ "$RECREATE" = "true" ]; then
        delete_cluster
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
