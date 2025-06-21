#!/bin/bash
set -e

# This script requires sudo privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run with sudo."
    exit 1
fi

# --- Variables and Constants ---
LOCAL_DOMAIN=${LOCAL_DOMAIN:-"local.dev"}
DNSMASQ_CONFIG_DIR="/opt/homebrew/etc/dnsmasq.d"
RESOLVER_DIR="/etc/resolver"

# --- Log Colors ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- Logging Functions ---
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Main Logic ---
main() {
    log_info "🚀 Starting host cleanup for domain '*.${LOCAL_DOMAIN}'..."

    # 1. Remove dnsmasq config
    if [ -f "$DNSMASQ_CONFIG_DIR/$LOCAL_DOMAIN.conf" ]; then
        rm -f "$DNSMASQ_CONFIG_DIR/$LOCAL_DOMAIN.conf"
        log_success "Dnsmasq config for '${LOCAL_DOMAIN}' removed."
    else
        log_warning "Dnsmasq config for '${LOCAL_DOMAIN}' not found. Skipping."
    fi

    # 2. Remove resolver file
    if [ -f "$RESOLVER_DIR/$LOCAL_DOMAIN" ]; then
        rm -f "$RESOLVER_DIR/$LOCAL_DOMAIN"
        log_success "Resolver file for '${LOCAL_DOMAIN}' removed."
    else
        log_warning "Resolver file for '${LOCAL_DOMAIN}' not found. Skipping."
    fi

    # 3. Restart dnsmasq and flush cache
    log_info "Restarting DNS services..."
    brew services restart dnsmasq > /dev/null
    dscacheutil -flushcache > /dev/null
    sudo killall -HUP mDNSResponder > /dev/null
    log_success "DNS services restarted."
    
    # 4. Remove state file
    if [ -f ".kind-lab.state" ]; then
        rm -f ".kind-lab.state"
        log_success "State file '.kind-lab.state' removed."
    fi

    log_info "🎉 Host cleanup complete."
}

main 