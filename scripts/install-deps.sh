#!/bin/bash

# Script to install dependencies for macOS
# This script installs all required tools for the kind-lab project

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install tool if not exists
install_tool() {
    local tool_name=$1
    local install_command=$2
    
    if command_exists "$tool_name"; then
        print_color $GREEN "✓ $tool_name is already installed"
    else
        print_color $YELLOW "Installing $tool_name..."
        eval "$install_command"
        print_color $GREEN "✓ $tool_name installed successfully"
    fi
}

print_color $BLUE "Installing dependencies for kind-lab..."

# Check if Homebrew is installed
if ! command_exists brew; then
    print_color $RED "Homebrew is not installed. Please install Homebrew first:"
    echo "https://brew.sh"
    exit 1
fi

# Update Homebrew
print_color $YELLOW "Updating Homebrew..."
brew update

# Install core tools
print_color $BLUE "Installing core tools..."

install_tool "kind" "brew install kind"
install_tool "kubectl" "brew install kubectl"
install_tool "helm" "brew install helm"
install_tool "mkcert" "brew install mkcert"
install_tool "dnsmasq" "brew install dnsmasq"

# Install additional tools
print_color $BLUE "Installing additional tools..."

install_tool "jq" "brew install jq"
install_tool "yq" "brew install yq"

# Install ArgoCD CLI
if command_exists argocd; then
    print_color $GREEN "✓ ArgoCD CLI is already installed"
else
    print_color $YELLOW "Installing ArgoCD CLI..."
    brew install argocd
    print_color $GREEN "✓ ArgoCD CLI installed successfully"
fi

# Setup mkcert root CA
print_color $BLUE "Setting up mkcert root CA..."
mkcert -install

# Start dnsmasq service
print_color $BLUE "Starting dnsmasq service..."
brew services start dnsmasq

# Verify installations
print_color $BLUE "Verifying installations..."

tools=("kind" "kubectl" "helm" "mkcert" "dnsmasq" "jq" "yq" "argocd")
for tool in "${tools[@]}"; do
    if command_exists "$tool"; then
        version=$($tool version 2>/dev/null || $tool --version 2>/dev/null || echo "version unknown")
        print_color $GREEN "✓ $tool: $version"
    else
        print_color $RED "✗ $tool: not found"
    fi
done

print_color $GREEN "All dependencies installed successfully!"
print_color $BLUE "Next steps:"
print_color $YELLOW "1. Run 'make configure-domain' to set up DNS and certificates"
print_color $YELLOW "2. Run 'make up' to create the cluster"
print_color $YELLOW "3. Run 'make install-argocd' to install ArgoCD"
