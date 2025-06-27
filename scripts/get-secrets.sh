#!/bin/bash

# Script to get secrets from cluster
# Usage: ./scripts/get-secrets.sh [namespace] [secret-name]

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

# Function to decode base64
decode_base64() {
    echo "$1" | base64 -d
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_color $RED "Error: kubectl not found. Install kubectl and try again."
    exit 1
fi

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    print_color $RED "Error: Cannot connect to cluster. Check kubectl context."
    exit 1
fi

# Default parameters
NAMESPACE=${1:-"ml-pipeline"}
SECRET_NAME=${2:-"ml-pipeline-secrets"}

print_color $BLUE "Getting secrets from namespace: $NAMESPACE"
print_color $BLUE "Secret: $SECRET_NAME"
echo

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    print_color $RED "Error: Namespace '$NAMESPACE' not found."
    exit 1
fi

# Check if secret exists
if ! kubectl get secret $SECRET_NAME -n $NAMESPACE &> /dev/null; then
    print_color $RED "Error: Secret '$SECRET_NAME' not found in namespace '$NAMESPACE'."
    exit 1
fi

# Get all keys from secret
print_color $GREEN "Available secrets:"
echo

# Get list of all keys
KEYS=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || \
       kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data}' | grep -o '"[^"]*"' | tr -d '"')

if [ -z "$KEYS" ]; then
    print_color $YELLOW "Secret is empty or contains no data."
    exit 0
fi

# Display each secret
for key in $KEYS; do
    print_color $YELLOW "=== $key ==="
    value=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath="{.data.$key}")
    if [ -n "$value" ]; then
        decoded_value=$(decode_base64 "$value")
        echo "$decoded_value"
    else
        print_color $RED "Value not found"
    fi
    echo
done

print_color $GREEN "To get a specific secret, use:"
print_color $BLUE "kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.KEY_NAME}' | base64 -d"
echo

print_color $GREEN "Examples:"
print_color $BLUE "kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.minio-root-password}' | base64 -d"
print_color $BLUE "kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.postgres-password}' | base64 -d" 