# Kind Lab - Local Kubernetes Development Environment
# Makefile for managing the development cluster and applications

.PHONY: help start-cluster stop-cluster status install-argocd install-minio install-postgresql install-redis install-mlflow uninstall-argocd uninstall-minio uninstall-postgresql uninstall-redis uninstall-mlflow upgrade-argocd upgrade-minio upgrade-postgresql upgrade-redis upgrade-mlflow status-argocd status-minio status-postgresql status-redis status-mlflow logs-argocd logs-minio logs-postgresql logs-redis logs-mlflow

# Get local domain from environment or use default
LOCAL_DOMAIN ?= beavers.dev

# Default target
help:
	@echo "Kind Lab - Local Kubernetes Development Environment"
	@echo ""
	@echo "Cluster Management:"
	@echo "  start-cluster    - Start Kind cluster with ingress and cert-manager"
	@echo "  stop-cluster     - Stop and delete Kind cluster"
	@echo "  status           - Show cluster status"
	@echo ""
	@echo "Application Management:"
	@echo "  install-argocd   - Install ArgoCD GitOps platform"
	@echo "  install-minio    - Install MinIO object storage"
	@echo "  install-postgresql - Install PostgreSQL database"
	@echo "  install-redis    - Install Redis database"
	@echo "  install-mlflow   - Install MLflow experiment tracking"
	@echo ""
	@echo "  upgrade-argocd   - Upgrade ArgoCD to latest version"
	@echo "  upgrade-minio    - Upgrade MinIO to latest version"
	@echo "  upgrade-postgresql - Upgrade PostgreSQL to latest version"
	@echo "  upgrade-redis    - Upgrade Redis to latest version"
	@echo "  upgrade-mlflow   - Upgrade MLflow to latest version"
	@echo ""
	@echo "  uninstall-argocd - Uninstall ArgoCD"
	@echo "  uninstall-minio  - Uninstall MinIO"
	@echo "  uninstall-postgresql - Uninstall PostgreSQL"
	@echo "  uninstall-redis  - Uninstall Redis"
	@echo "  uninstall-mlflow - Uninstall MLflow"
	@echo ""
	@echo "  status-argocd    - Show ArgoCD status"
	@echo "  status-minio     - Show MinIO status"
	@echo "  status-postgresql - Show PostgreSQL status"
	@echo "  status-redis     - Show Redis status"
	@echo "  status-mlflow    - Show MLflow status"
	@echo ""
	@echo "  logs-argocd      - Show ArgoCD logs"
	@echo "  logs-minio       - Show MinIO logs"
	@echo "  logs-postgresql  - Show PostgreSQL logs"
	@echo "  logs-redis       - Show Redis logs"
	@echo "  logs-mlflow      - Show MLflow logs"
	@echo ""
	@echo "Access URLs (domain: $(LOCAL_DOMAIN)):"
	@echo "  ArgoCD:          https://argo.$(LOCAL_DOMAIN)"
	@echo "  MinIO Console:   https://minio-console.$(LOCAL_DOMAIN)"
	@echo "  MinIO API:       https://minio.$(LOCAL_DOMAIN)"
	@echo "  MLflow:          https://mlflow.$(LOCAL_DOMAIN)"
	@echo ""
	@echo "Local Access (port-forward):"
	@echo "  PostgreSQL:      localhost:5433 (kubectl port-forward -n postgresql svc/postgresql 5433:5432)"
	@echo "  Redis:           localhost:6380 (kubectl port-forward -n redis svc/redis-master 6380:6379)"
	@echo ""
	@echo "Environment variables:"
	@echo "  LOCAL_DOMAIN     - Local domain (default: beavers.dev)"
	@echo "  Load from .env file for credentials"
	@echo "  View credentials: cat .env"

# Cluster management
start-cluster:
	@echo "Starting Kind cluster..."
	@./scripts/setup-cluster.sh

stop-cluster:
	@echo "Stopping Kind cluster..."
	@kind delete cluster --name kind-lab

status:
	@echo "Cluster Status:"
	@kubectl cluster-info
	@echo ""
	@echo "Nodes:"
	@kubectl get nodes
	@echo ""
	@echo "Namespaces:"
	@kubectl get namespaces
	@echo ""
	@echo "Ingress Controller:"
	@kubectl get pods -n ingress-nginx

# ArgoCD management
install-argocd:
	@echo "Installing ArgoCD..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-argocd.sh install

upgrade-argocd:
	@echo "Upgrading ArgoCD..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-argocd.sh upgrade

uninstall-argocd:
	@echo "Uninstalling ArgoCD..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-argocd.sh uninstall

status-argocd:
	@echo "ArgoCD Status:"
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-argocd.sh status

logs-argocd:
	@echo "ArgoCD Logs:"
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-argocd.sh logs

# MinIO management
install-minio:
	@echo "Installing MinIO..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-minio.sh install

upgrade-minio:
	@echo "Upgrading MinIO..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-minio.sh upgrade

uninstall-minio:
	@echo "Uninstalling MinIO..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-minio.sh uninstall

status-minio:
	@echo "MinIO Status:"
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-minio.sh status

logs-minio:
	@echo "MinIO Logs:"
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-minio.sh logs

# PostgreSQL management
install-postgresql:
	@echo "Installing PostgreSQL..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-postgresql.sh install

upgrade-postgresql:
	@echo "Upgrading PostgreSQL..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-postgresql.sh upgrade

uninstall-postgresql:
	@echo "Uninstalling PostgreSQL..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-postgresql.sh uninstall

status-postgresql:
	@echo "PostgreSQL Status:"
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-postgresql.sh status

logs-postgresql:
	@echo "PostgreSQL Logs:"
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-postgresql.sh logs

# Redis management
install-redis:
	@echo "Installing Redis..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-redis.sh install

upgrade-redis:
	@echo "Upgrading Redis..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-redis.sh upgrade

uninstall-redis:
	@echo "Uninstalling Redis..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-redis.sh uninstall

status-redis:
	@echo "Redis Status:"
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-redis.sh status

logs-redis:
	@echo "Redis Logs:"
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-redis.sh logs

# MLflow management
install-mlflow:
	@echo "Installing MLflow..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-mlflow.sh install

upgrade-mlflow:
	@echo "Upgrading MLflow..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-mlflow.sh upgrade

uninstall-mlflow:
	@echo "Uninstalling MLflow..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-mlflow.sh uninstall

status-mlflow:
	@echo "MLflow Status:"
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-mlflow.sh status

logs-mlflow:
	@echo "MLflow Logs:"
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-mlflow.sh logs 