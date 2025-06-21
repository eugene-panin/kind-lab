#!/bin/bash
set -e

# --- Variables and Constants ---
# Names and domains are taken from the environment (from .env) with a fallback to default values
CLUSTER_NAME=${CLUSTER_NAME:-"kind-lab"}
LOCAL_DOMAIN=${LOCAL_DOMAIN:-"local.dev"}

# Paths
CERTS_DIR="$(pwd)/certs"
CERT_FILE="$CERTS_DIR/cert.pem"
KEY_FILE="$CERTS_DIR/key.pem"
STATE_FILE=".kind-lab.state"
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

# Function to remove old configurations
cleanup_old_domain() {
    local old_domain="$1"
    log_warning "Domain change detected from '$old_domain' to '$LOCAL_DOMAIN'. Removing old configurations..."
    
    # Remove dnsmasq config
    if [ -f "$DNSMASQ_CONFIG_DIR/$old_domain.conf" ]; then
        rm -f "$DNSMASQ_CONFIG_DIR/$old_domain.conf"
        log_success "Old dnsmasq config removed."
    fi

    # Remove resolver file
    if [ -f "$RESOLVER_DIR/$old_domain" ]; then
        rm -f "$RESOLVER_DIR/$old_domain"
        log_success "Old resolver file removed."
    fi

    # Restart dnsmasq
    brew services restart dnsmasq > /dev/null
    # Flush DNS cache
    dscacheutil -flushcache > /dev/null
    sudo killall -HUP mDNSResponder > /dev/null
    log_success "DNS services restarted."
}


# --- Main Logic ---
main() {
    log_info "🚀 Starting host setup script..."
    log_info "Using domain: *.$LOCAL_DOMAIN"

    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run with sudo. Please use 'make configure-domain'."
        exit 1
    fi
    
    # Get the regular user's name to run mkcert
    REGULAR_USER=${SUDO_USER:-$(whoami)}

    # 1. Check if the domain has changed since the last run
    if [ -f "$STATE_FILE" ]; then
        LAST_DOMAIN=$(grep 'LAST_DOMAIN' "$STATE_FILE" | cut -d '=' -f 2)
        if [ -n "$LAST_DOMAIN" ] && [ "$LAST_DOMAIN" != "$LOCAL_DOMAIN" ]; then
            cleanup_old_domain "$LAST_DOMAIN"
        fi
    fi

    # 2. Configure dnsmasq
    log_info "Configuring dnsmasq..."
    mkdir -p "$DNSMASQ_CONFIG_DIR"
    echo "address=/.$LOCAL_DOMAIN/127.0.0.1" > "$DNSMASQ_CONFIG_DIR/$LOCAL_DOMAIN.conf"
    log_success "dnsmasq configuration file created."

    # 3. Configure macOS system resolver
    log_info "Configuring macOS system resolver..."
    mkdir -p "$RESOLVER_DIR"
    echo "nameserver 127.0.0.1" > "$RESOLVER_DIR/$LOCAL_DOMAIN"
    log_success "System resolver configured."

    # 4. Restart services
    log_info "Restarting DNS services..."
    brew services restart dnsmasq > /dev/null
    dscacheutil -flushcache > /dev/null
    sudo killall -HUP mDNSResponder > /dev/null
    log_success "DNS services restarted successfully."

    # 5. Generate certificates
    log_info "Generating SSL certificates..."
    # mkcert must be run as the regular user to find its CA
    # Create the directory as the user if it doesn't exist
    sudo -u "$REGULAR_USER" mkdir -p "$CERTS_DIR"
    # Generate the certificate
    sudo -u "$REGULAR_USER" mkcert -cert-file "$CERT_FILE" -key-file "$KEY_FILE" *."$LOCAL_DOMAIN"
    log_success "Certificates for '*.${LOCAL_DOMAIN}' generated successfully."

    # 6. Save state
    echo "LAST_DOMAIN=$LOCAL_DOMAIN" > "$STATE_FILE"
    chown "$REGULAR_USER" "$STATE_FILE"
    log_success "Domain state saved."

    log_info "🎉 Host setup successful for domain '*.${LOCAL_DOMAIN}'."
}

main 