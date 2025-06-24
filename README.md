# Kind Lab

A local Kubernetes development environment using Kind (Kubernetes in Docker) with automatic DNS resolution, TLS certificates, and ingress setup for macOS.

## Features

- 🚀 **One-command cluster setup** with Kind
- 🌐 **Automatic DNS resolution** for custom domains (e.g., `*.beavers.dev`)
- 🔒 **TLS certificates** with mkcert for secure local development
- 📦 **NGINX Ingress Controller** for routing traffic
- 🎯 **Live-reload** for application files
- 🧹 **Easy cleanup** and resource management

## Prerequisites

- macOS (tested on macOS 14+)
- Homebrew
- Docker Desktop

## Quick Start

### 1. Install dependencies
```bash
make deps
```
Installs: kind, kubectl, helm, mkcert, dnsmasq

### 2. Configure domain and certificates (requires sudo)
```bash
sudo make configure-domain
```
Creates TLS certificates, configures dnsmasq and system resolver for your domain.

### 3. Start the cluster
```bash
make up
```
Creates the cluster, applies manifests, deploys ingress and status page.

### 4. Clean up cluster and artifacts
```bash
make clean
```
Removes cluster, certificates, and state files.

### 5. (Optional) Complete system cleanup
```bash
sudo ./scripts/uninstall-deps.sh
```
Removes dnsmasq configs, resolver files, and mkcert root CA from system.

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and modify as needed:

```bash
cp .env.example .env
```

Available variables:
- `CLUSTER_NAME` - Name of the Kind cluster (default: `beavers-lab`)
- `LOCAL_DOMAIN` - Local domain for services (default: `beavers.dev`)

### Changing Local Domain

To change the local domain:

1. **Update .env file:**
   ```bash
   echo "LOCAL_DOMAIN=my-new-domain.dev" > .env
   ```

2. **Clean up old configuration:**
   ```bash
   make clean
   ```

3. **Configure new domain (requires sudo):**
   ```bash
   sudo make configure-domain
   ```

4. **Start cluster with new domain:**
   ```bash
   make up
   ```

**Note:** After changing the domain, old URLs (e.g., `https://status.beavers.dev`) will stop working. New URLs will be `https://status.my-new-domain.dev`.

## Available Commands

```bash
make deps               # Install required tools (kind, kubectl, helm, mkcert)
make configure-domain   # (sudo) Configure DNS and generate TLS certificates
make up                 # Create/recreate and start the cluster
make start              # Alias for 'up'
make down               # Stop and delete the cluster
make clean              # Delete cluster and all generated files
make help               # Show this help message
```

## Services

Once the cluster is running, the following services are available:

- **Status Page**: https://status.beavers.dev
- **Kubernetes Dashboard**: Access via `kubectl proxy`
- **Ingress Controller**: NGINX Ingress Controller

## Development

### Live Reload

Application files in `src/status-app/` are mounted into the cluster and support live reloading. Changes to `index.html` are reflected immediately.

### Adding Applications

To add new applications:

1. Create manifests in `k8s/` directory
2. Add ingress rules for your domain
3. Apply with `kubectl apply -f k8s/your-app.yaml`

### Custom Domains

All services can be accessed via subdomains of your configured `LOCAL_DOMAIN`:
- `https://your-app.beavers.dev`
- `https://api.beavers.dev`
- etc.

## Troubleshooting

### DNS Resolution Issues

If `*.beavers.dev` doesn't resolve:

1. Check dnsmasq status:
   ```bash
   brew services list | grep dnsmasq
   ```

2. Restart dnsmasq:
   ```bash
   sudo brew services restart dnsmasq
   ```

3. Test DNS resolution:
   ```bash
   dig status.beavers.dev @127.0.0.1
   ```

### Certificate Issues

If you see certificate warnings:

1. Ensure mkcert root CA is installed:
   ```bash
   mkcert -install
   ```

2. Regenerate certificates:
   ```bash
   sudo make configure-domain
   ```

### Cluster Creation Issues

If cluster creation fails with "node(s) already exist":

1. Clean up manually:
   ```bash
   kind delete cluster --name beavers-lab
   docker rm -f $(docker ps -a | grep beavers-lab | awk '{print $1}')
   ```

2. Try again:
   ```bash
   make up
   ```

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Local Files   │    │   Kind Cluster  │    │   Applications  │
│                 │    │                 │    │                 │
│ src/status-app/ │───▶│   NGINX Ingress │───▶│  Status Page    │
│                 │    │   Controller    │    │  Your Apps      │
│ k8s/manifests/  │───▶│   TLS Secrets   │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │   DNS (dnsmasq) │
                       │   *.beavers.dev │
                       └─────────────────┘
```

## License

MIT License - see [LICENSE](LICENSE) file for details.
