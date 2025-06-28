#!/bin/bash

# Kafka Management Script for kind-lab
# Handles installation, upgrade, uninstallation, status checking, and log viewing

set -e

# Configuration
RELEASE_NAME="kafka"
NAMESPACE="kafka"
CHART_NAME="bitnami/kafka"
CHART_VERSION="22.1.5"  # Downgraded to a stable version for Zookeeper mode

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
            sed "s/name: wildcard-tls/name: kafka-tls/" | \
            kubectl apply -f -
        print_status "TLS certificates copied successfully."
    else
        print_warning "TLS certificate not found in cert-manager namespace."
    fi
}

# Function to install Kafka
install() {
    print_header "Installing Kafka"
    
    check_prerequisites
    load_env
    add_repo
    create_namespace
    copy_tls_certs
    
    print_status "Installing Kafka with Helm..."
    
    # Create values file with environment substitution
    VALUES_FILE="/tmp/kafka-values.yaml"
    envsubst < extensions/kafka/values.yaml > $VALUES_FILE
    
    helm install $RELEASE_NAME $CHART_NAME \
        --namespace $NAMESPACE \
        --version $CHART_VERSION \
        --values $VALUES_FILE \
        --wait \
        --timeout 15m
    
    print_status "Kafka installation completed!"
    print_status "Access URL: https://kafka.$LOCAL_DOMAIN"
    print_status "Kafka broker: kafka.kafka.svc.cluster.local:9092"
    
    # Clean up temporary file
    rm -f $VALUES_FILE
}

# Function to upgrade Kafka
upgrade() {
    print_header "Upgrading Kafka"
    
    check_prerequisites
    load_env
    add_repo
    
    print_status "Upgrading Kafka with Helm..."
    
    # Create values file with environment substitution
    VALUES_FILE="/tmp/kafka-values.yaml"
    envsubst < extensions/kafka/values.yaml > $VALUES_FILE
    
    helm upgrade $RELEASE_NAME $CHART_NAME \
        --namespace $NAMESPACE \
        --version $CHART_VERSION \
        --values $VALUES_FILE \
        --wait \
        --timeout 15m
    
    print_status "Kafka upgrade completed!"
    
    # Clean up temporary file
    rm -f $VALUES_FILE
}

# Function to uninstall Kafka
uninstall() {
    print_header "Uninstalling Kafka"
    
    print_status "Uninstalling Kafka with Helm..."
    helm uninstall $RELEASE_NAME --namespace $NAMESPACE --wait
    
    print_status "Deleting namespace: $NAMESPACE"
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    
    print_status "Kafka uninstallation completed!"
}

# Function to show status
status() {
    print_header "Kafka Status"
    
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
    
    # Check if Kafka is ready
    if kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=kafka --no-headers | grep -q "Running"; then
        print_status "Kafka is running and ready!"
        print_status "Access URL: https://kafka.$LOCAL_DOMAIN"
        print_status "Kafka broker: kafka.kafka.svc.cluster.local:9092"
    else
        print_warning "Kafka is not ready yet. Check the logs for more information."
    fi
}

# Function to show logs
logs() {
    print_header "Kafka Logs"
    
    # Get the Kafka pod name
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=kafka -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$POD_NAME" ]; then
        print_error "No Kafka pods found in namespace $NAMESPACE"
        exit 1
    fi
    
    print_status "Showing logs for pod: $POD_NAME"
    kubectl logs -n $NAMESPACE $POD_NAME -f
}

# Function to create topic
create_topic() {
    if [ -z "$1" ]; then
        print_error "Please provide a topic name"
        echo "Usage: $0 create-topic <topic-name>"
        exit 1
    fi
    
    TOPIC_NAME=$1
    print_header "Creating Kafka Topic: $TOPIC_NAME"
    
    # Get Kafka pod name
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=kafka -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$POD_NAME" ]; then
        print_error "No Kafka pods found in namespace $NAMESPACE"
        exit 1
    fi
    
    print_status "Creating topic: $TOPIC_NAME"
    kubectl exec -n $NAMESPACE $POD_NAME -- kafka-topics.sh --create \
        --bootstrap-server localhost:9092 \
        --replication-factor 1 \
        --partitions 3 \
        --topic $TOPIC_NAME
    
    print_status "Topic $TOPIC_NAME created successfully!"
}

# Function to list topics
list_topics() {
    print_header "Listing Kafka Topics"
    
    # Get Kafka pod name
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=kafka -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$POD_NAME" ]; then
        print_error "No Kafka pods found in namespace $NAMESPACE"
        exit 1
    fi
    
    print_status "Listing topics:"
    kubectl exec -n $NAMESPACE $POD_NAME -- kafka-topics.sh --list \
        --bootstrap-server localhost:9092
}

# Function to show help
show_help() {
    echo "Kafka Management Script for kind-lab"
    echo ""
    echo "Usage: $0 {install|upgrade|uninstall|status|logs|create-topic|list-topics}"
    echo ""
    echo "Commands:"
    echo "  install        - Install Kafka with UI"
    echo "  upgrade        - Upgrade Kafka to latest version"
    echo "  uninstall      - Uninstall Kafka"
    echo "  status         - Show Kafka status"
    echo "  logs           - Show Kafka logs"
    echo "  create-topic   - Create a new Kafka topic"
    echo "  list-topics    - List all Kafka topics"
    echo ""
    echo "Environment variables (load from .env file):"
    echo "  LOCAL_DOMAIN   - Local domain (default: beavers.dev)"
    echo ""
    echo "Access URL: https://kafka.\$LOCAL_DOMAIN"
    echo "Kafka broker: kafka.kafka.svc.cluster.local:9092"
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
    create-topic)
        create_topic "$2"
        ;;
    list-topics)
        list_topics
        ;;
    *)
        show_help
        exit 1
        ;;
esac 