#!/bin/bash
set -e

# --- Colors for logging ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- Logging functions ---
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Installation functions ---
install_homebrew() {
    if ! command -v brew &> /dev/null; then
        log_info "Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        log_success "Homebrew installed successfully."
    else
        log_info "Homebrew is already installed. Updating..."
        brew update
        log_success "Homebrew updated."
    fi
}

install_packages() {
    log_info "Installing packages for macOS..."
    # Check and install packages if they are not already installed
    for pkg in helm kind kubectl mkcert dnsmasq; do
        if brew list $pkg &>/dev/null; then
            log_info "$pkg is already installed."
        else
            log_info "Installing $pkg..."
            brew install $pkg
        fi
    done

    log_info "Installing mkcert root CA..."
    mkcert -install
    
    log_info "Starting dnsmasq service..."
    brew services start dnsmasq
    log_success "macOS packages installed and configured."
}

# --- Main logic ---
log_info "Starting dependency installation for macOS..."
install_homebrew
install_packages
log_success "All dependencies are installed."
