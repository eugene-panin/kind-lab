# Kind Lab

A local Kubernetes development environment using Kind (Kubernetes in Docker) with automatic DNS resolution, TLS certificates, and GitOps infrastructure for macOS.

## Features

- 🚀 **One-command cluster setup** with Kind
- 🌐 **Automatic DNS resolution** for custom domains (e.g., `*.beavers.dev`)
- 🔒 **TLS certificates** with mkcert for secure local development
- 📦 **NGINX Ingress Controller** for routing traffic
- 🎯 **Live-reload** for application files
- 🧹 **Easy cleanup** and resource management
- 🔄 **GitOps infrastructure** with ArgoCD
- 📓 **JupyterHub** for data science and development

## Architecture

This project follows a **separation of concerns** approach:

### 🏗️ **kind-lab** (Infrastructure Layer)
- **Cluster management** (Kind, DNS, TLS)
- **GitOps platform** (ArgoCD)
- **Development tools** (JupyterHub)

### 🚀 **External Repositories** (Application Layer)
- **ml-pipeline** - ML/Data processing applications
- **user-service** - User management services
- **api-gateway** - API gateway and routing
- **frontend-app** - Web applications

## Prerequisites

- macOS (tested on macOS 14+)
- Homebrew
- Docker Desktop

## Quick Start

### 1. Install dependencies
```bash
make deps
```
Installs: kind, kubectl, helm, mkcert, dnsmasq, argocd

### 2. Configure domain and certificates (requires sudo)
```bash
sudo make configure-domain
```
Creates TLS certificates, configures dnsmasq and system resolver for your domain.

### 3. Start the cluster and install ArgoCD
```bash
make setup-complete
```
Creates the cluster, installs ArgoCD, and deploys status page.

### 4. Install JupyterHub (optional)
```bash
make install-jh
```
Installs JupyterHub for data science and development.

### 5. Clean up cluster and artifacts
```bash
make clean
```
Removes cluster, certificates, and state files.

### 6. (Optional) Complete system cleanup
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
- `CLUSTER_NAME` - Name of the Kind cluster (default: `kind-lab`)
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
make deps               # Install required tools (kind, kubectl, helm, mkcert, dnsmasq, argocd)
make configure-domain   # (sudo) Configure DNS and generate TLS certificates
make up                 # Create/recreate and start the cluster
make start              # Alias for 'up'
make down               # Stop and delete the cluster
make clean              # Delete cluster and all generated files (certs, state)
make help               # Show this help message

# ArgoCD
make install-argocd     # Install ArgoCD GitOps platform
make setup-complete     # Complete setup: cluster + ArgoCD
make teardown-complete  # Complete teardown of all components

# JupyterHub
make install-jh         # Install JupyterHub
```

## Services

Once the cluster is running, the following services are available:

- **Status Page**: https://status.beavers.dev
- **ArgoCD**: https://argo.beavers.dev
- **JupyterHub**: https://jupyter.beavers.dev

## Infrastructure Components

### 🔄 GitOps
- **ArgoCD** - GitOps continuous delivery platform
- **Application management** - Deploy applications from external repositories

### 📓 Development Tools
- **JupyterHub** - Multi-user Jupyter notebook server
- **Dummy Authenticator** - Simple authentication for local development

### 🔒 TLS Certificates
- **mkcert** - Local development certificates (wildcard `*.beavers.dev`)
- **Manual secret creation** - `kubectl create secret tls local-dev-tls`
- **No cert-manager needed** - Simple and fast for local development

## Development

### Live Reload

Application files in `src/status-app/` are mounted into the cluster and support live reloading. Changes to `index.html` are reflected immediately.

### Adding Applications

To add new applications:

1. **Create a new repository** for your application
2. **Add Kubernetes manifests** in the `k8s/` directory
3. **Configure ArgoCD** to deploy from your repository

### Custom Domains

All services can be accessed via subdomains of your configured `LOCAL_DOMAIN`:
- `https://your-app.beavers.dev`
- `https://api.beavers.dev`
- etc.

## Repository Structure

```
kind-lab/
├── certs/                    # TLS certificates
├── extensions/               # Helm values for infrastructure
│   ├── argocd/              # ArgoCD configuration
│   └── jupyterhub/          # JupyterHub configuration
├── k8s/                      # Kubernetes manifests
│   ├── kind-config.yaml      # Kind cluster config
│   └── status-app.yaml       # Status page
├── scripts/                  # Management scripts
├── src/                      # Application source code
│   └── status-app/           # Status page
└── README.md
```

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
   kind delete cluster --name kind-lab
   docker rm -f $(docker ps -a | grep kind-lab | awk '{print $1}')
   ```

2. Try again:
   ```bash
   make up
   ```

### ArgoCD Issues

1. Check ArgoCD status:
   ```bash
   kubectl get pods -n argocd
   ```

2. Access ArgoCD UI:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

3. Get admin password:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
   ```

### JupyterHub Issues

1. Check JupyterHub status:
   ```bash
   kubectl get pods -n jupyterhub
   ```

2. Check ingress configuration:
   ```bash
   kubectl get ingress -n jupyterhub
   ```

3. Verify TLS secret:
   ```bash
   kubectl get secret local-dev-tls -n jupyterhub
   ```

## Architecture Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Local Files   │    │   Kind Cluster  │    │   Applications  │
│                 │    │                 │    │                 │
│ src/status-app/ │───▶│   NGINX Ingress │───▶│  Status Page    │
│                 │    │   Controller    │    │  JupyterHub     │
│ k8s/manifests/  │───▶│   TLS Secrets   │    │  Your Apps      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │   DNS (dnsmasq) │
                       │   *.beavers.dev │
                       └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │   ArgoCD        │
                       │   GitOps        │
                       └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │   External      │
                       │   Repositories  │
                       └─────────────────┘
```

## License

MIT License - see [LICENSE](LICENSE) file for details.
