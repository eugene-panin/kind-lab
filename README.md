# Kind Lab - Local Kubernetes Development Environment

A local Kubernetes development environment using Kind (Kubernetes in Docker) with automatic DNS resolution, TLS certificates, and essential services for development and testing.

## Features

- **Multi-node Kind cluster** with 3 nodes (1 control-plane + 2 workers)
- **Automatic DNS resolution** for `*.beavers.dev` domain
- **TLS certificates** via mkcert for secure HTTPS access
- **NGINX Ingress Controller** for routing traffic
- **ArgoCD** for GitOps workflows
- **MinIO** object storage with S3-compatible API
- **PostgreSQL** database with NodePort access
- **Redis** database with NodePort access
- **Local Path Provisioner** for lightweight persistent storage
- **Environment-based configuration** via `.env` file

## Quick Start

### Prerequisites

- Docker Desktop
- Kind
- kubectl
- Helm
- mkcert

Install dependencies:
```bash
make install-deps
```

### Setup

1. **Configure environment:**
```bash
# Copy example environment file
cp env.example .env

# Edit .env file with your preferences
# LOCAL_DOMAIN=beavers.dev
# MINIO_ADMIN=minioadmin
# MINIO_ADMIN_PASSWORD=minioadmin123
# ARGO_ADMIN=admin
# ARGO_ADMIN_PASSWORD=admin123
```

2. **Configure domain and certificates:**
```bash
make configure-host
```

3. **Start the cluster:**
```bash
make start-cluster
```

4. **Install services:**
```bash
# Install ArgoCD
make install-argocd

# Install MinIO
make install-minio

# Install PostgreSQL
make install-postgresql

# Install Redis
make install-redis
```

## Access URLs

### HTTP/HTTPS Services (via Ingress)
- **Status Page:** https://status.beavers.dev
- **ArgoCD:** https://argo.beavers.dev
- **MinIO Console:** https://minio-console.beavers.dev
- **MinIO API:** https://minio.beavers.dev

### TCP Services (via Port-Forward)
- **PostgreSQL:** localhost:5433 (via port-forward)
  - Database: `lab`
  - User: `postgres`
  - Password: `postgres123`
  - Start port-forward: `kubectl port-forward -n postgresql svc/postgresql 5433:5432`
- **Redis:** localhost:6380 (via port-forward)
  - No authentication (development mode)
  - Start port-forward: `kubectl port-forward -n redis svc/redis-master 6380:6379`

## Architecture

### **Stateless Approach**
This project is designed for **stateless development**:

- **VSCode + Local Git** - for notebook development and versioning
- **MinIO** - for data storage (datasets, models, artifacts)
- **ArgoCD** - for GitOps automation
- **Kind Cluster** - for heavy computations when needed

### **Data Storage Structure**
```
MinIO Buckets:
├── datasets/          # Raw and processed datasets
├── models/           # Trained models
├── artifacts/        # Experiment artifacts
└── cache/           # Computation cache
```

## Management Commands

### Cluster Management
```bash
make start-cluster    # Start Kind cluster with ingress and storage
make stop-cluster     # Stop and delete Kind cluster
make status           # Show cluster status
```

### Application Management
```bash
# Install
make install-argocd   # Install ArgoCD GitOps platform
make install-minio    # Install MinIO object storage
make install-postgresql # Install PostgreSQL database
make install-redis    # Install Redis database

# Upgrade
make upgrade-argocd   # Upgrade ArgoCD to latest version
make upgrade-minio    # Upgrade MinIO to latest version
make upgrade-postgresql # Upgrade PostgreSQL to latest version
make upgrade-redis    # Upgrade Redis to latest version

# Uninstall
make uninstall-argocd # Uninstall ArgoCD
make uninstall-minio  # Uninstall MinIO
make uninstall-postgresql # Uninstall PostgreSQL
make uninstall-redis  # Uninstall Redis

# Status
make status-argocd    # Show ArgoCD status
make status-minio     # Show MinIO status
make status-postgresql # Show PostgreSQL status
make status-redis     # Show Redis status

# Logs
make logs-argocd      # Show ArgoCD logs
make logs-minio       # Show MinIO logs
make logs-postgresql  # Show PostgreSQL logs
make logs-redis       # Show Redis logs
```

## Configuration

### Environment Variables (.env file)
```bash
# Local domain configuration
LOCAL_DOMAIN=beavers.dev

# MinIO configuration
MINIO_ADMIN=minioadmin
MINIO_ADMIN_PASSWORD=minioadmin123

# ArgoCD configuration
ARGO_ADMIN=admin
ARGO_ADMIN_PASSWORD=admin123

# PostgreSQL configuration
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres123
POSTGRES_DB=lab

# Jupyter user for MinIO (optional)
MINIO_JUPYTER_USER=jupyter
MINIO_JUPYTER_PASSWORD=jupyter123
```

### Custom Values
Each service can be customized by editing the corresponding values file:
- `extensions/argocd/values.yaml` - ArgoCD configuration
- `extensions/minio/values.yaml` - MinIO configuration
- `extensions/postgresql/values.yaml` - PostgreSQL configuration
- `extensions/redis/values.yaml` - Redis configuration

## Development Workflow

### **Local Development (VSCode)**
1. **Create local Git repository** for notebooks
2. **Work in VSCode** with Jupyter extension
3. **Use MinIO for data** via S3 API
4. **Version control** notebooks in Git

### **MinIO Integration**
```python
# Example Python code for MinIO access
import boto3
import pandas as pd

# Connect to MinIO
s3 = boto3.client('s3',
    endpoint_url='https://minio.beavers.dev',
    aws_access_key_id='minioadmin',
    aws_secret_access_key='minioadmin',
    verify=False  # For self-signed certificates

# Upload dataset
s3.upload_file('data/train.csv', 'datasets', 'train.csv')

# Download dataset
s3.download_file('datasets', 'train.csv', 'data/train.csv')
df = pd.read_csv('data/train.csv')
```

### **PostgreSQL Integration**
```python
# Example Python code for PostgreSQL access
import psycopg2
import pandas as pd

# Connect to PostgreSQL (via port-forward)
conn = psycopg2.connect(
    host='localhost',
    port=5432,  # Port-forward
    database='lab',
    user='postgres',
    password='postgres123'
)

# Execute queries
df = pd.read_sql_query("SELECT * FROM your_table", conn)
conn.close()
```

**Note:** Start port-forward first: `kubectl port-forward -n postgresql svc/postgresql 5432:5432`

### **ArgoCD for Automation**
- **GitOps workflows** for infrastructure
- **Automated deployments** from Git repositories
- **Environment management** across different stages

### **Redis Integration**
```python
# Example Python code for Redis access
import redis

# Connect to Redis (via port-forward)
r = redis.Redis(host='localhost', port=6380, decode_responses=True)

# Set and get values
r.set('key', 'value')
value = r.get('key')

# Use Redis for caching
r.setex('cache_key', 3600, 'cached_data')  # Expire in 1 hour
```

**Note:** Start port-forward first: `kubectl port-forward -n redis svc/redis-master 6380:6379`

## Storage

The cluster uses **Local Path Provisioner** for lightweight persistent storage:
- Fast and simple for local development
- No external dependencies
- Suitable for single-node workloads

Services like MinIO use Local Path Provisioner for their persistent volumes.

## Troubleshooting

### Common Issues

1. **DNS resolution not working:**
   ```bash
   make configure-host
   ```

2. **TLS certificate errors:**
   ```bash
   make configure-host
   make start-cluster
   ```

3. **Service not accessible:**
   ```bash
   kubectl get pods -A
   kubectl get ingress -A
   ```

### Logs and Debugging
```bash
# Check service logs
make logs-<service>

# Check pod status
kubectl get pods -A

# Check ingress status
kubectl get ingress -A

# Check storage
kubectl get pvc -A
kubectl get pv
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

Access patterns:
  - HTTP/HTTPS services: https://service.beavers.dev (via Ingress)
  - TCP services: localhost:PORT (via kubectl port-forward)
