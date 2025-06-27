# Makefile for managing the local Kubernetes environment for macOS

# --- Configuration ---
# Include .env file if it exists. It will override the default values below.
-include .env
export

# Use `?=` to set default values, which can be overridden by the .env file.
CLUSTER_NAME ?= kind-lab
LOCAL_DOMAIN ?= beavers.dev

# Tool versions. Use `?=` so .env can override them.
# Note: These are currently for reference only, as Homebrew manages the versions.
# They are kept here for future reference.
HELM_VERSION ?= v3.18.3
KIND_VERSION ?= v0.29.0
KUBECTL_VERSION ?= v1.33.2
MKCERT_VERSION ?= v1.4.4


# --- Main Targets ---
.PHONY: up start down clean deps configure-domain

up: start
start:
	@echo "--> 🚀 Creating and setting up the cluster for domain '*.$(LOCAL_DOMAIN)'..."
	@./scripts/setup-cluster.sh

down:
	@echo "--> 🌊 Stopping and deleting the cluster..."
	@kind delete cluster --name "$(CLUSTER_NAME)"

clean: down
	@echo "--> 🧹 Cleaning up generated files..."
	@rm -rf ./certs ./.kind-lab.state
	@echo "--> ℹ️ To completely remove host configuration, run 'sudo ./scripts/uninstall-deps.sh' manually."

deps:
	@echo "--> 📦 Installing dependencies for macOS..."
	@./scripts/install-deps.sh

configure-domain:
	@echo "--> 🌐 Configuring local domain and TLS certificates..."
	@sudo LOCAL_DOMAIN=$(LOCAL_DOMAIN) CLUSTER_NAME=$(CLUSTER_NAME) ./scripts/configure-host.sh

# --- ArgoCD Management ---
.PHONY: install-argocd update-argocd uninstall-argocd status-argocd

install-argocd:
	@echo "--> 🔄 Installing ArgoCD GitOps platform..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-argocd.sh install

update-argocd:
	@echo "--> 🔄 Updating ArgoCD..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-argocd.sh update

uninstall-argocd:
	@echo "--> 🗑️ Uninstalling ArgoCD..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-argocd.sh uninstall

status-argocd:
	@echo "--> 📊 Checking ArgoCD status..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-argocd.sh status

# --- JupyterHub Management ---
.PHONY: install-jh update-jh uninstall-jh status-jh

install-jh:
	@echo "--> 📓 Installing JupyterHub..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-jupyterhub.sh install

update-jh:
	@echo "--> 📓 Updating JupyterHub..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-jupyterhub.sh update

uninstall-jh:
	@echo "--> 🗑️ Uninstalling JupyterHub..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-jupyterhub.sh uninstall

status-jh:
	@echo "--> 📊 Checking JupyterHub status..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/manage-jupyterhub.sh status

# --- Complete Setup/Teardown ---
.PHONY: setup-complete teardown-complete

setup-complete: up install-argocd
	@echo "--> 🎉 Complete setup finished!"
	@echo "--> 📊 Access ArgoCD at: https://argo.$(LOCAL_DOMAIN)"

teardown-complete: clean
	@echo "--> 🧹 Complete teardown finished!"

# --- Help ---
.PHONY: help
help:
	@echo "Available commands:"
	@echo "  make up                 - Create/recreate and start the cluster."
	@echo "  make start              - Alias for 'up'."
	@echo "  make down               - Stop and delete the cluster."
	@echo "  make clean              - Delete the cluster and all generated files (certs, state)."
	@echo "  make deps               - Install required tools for macOS (kind, kubectl, helm, mkcert)."
	@echo "  make configure-domain   - (sudo) Configure DNS and generate TLS certificates for the local domain."
	@echo ""
	@echo "ArgoCD Management:"
	@echo "  make install-argocd     - Install ArgoCD GitOps platform"
	@echo "  make update-argocd      - Update ArgoCD to latest version"
	@echo "  make uninstall-argocd   - Remove ArgoCD completely"
	@echo "  make status-argocd      - Show ArgoCD status and access info"
	@echo ""
	@echo "JupyterHub Management:"
	@echo "  make install-jh         - Install JupyterHub"
	@echo "  make update-jh          - Update JupyterHub to latest version"
	@echo "  make uninstall-jh       - Remove JupyterHub completely"
	@echo "  make status-jh          - Show JupyterHub status and access info"
	@echo ""
	@echo "Complete Setup/Teardown:"
	@echo "  make setup-complete     - Complete setup: cluster + ArgoCD"
	@echo "  make teardown-complete  - Complete teardown of all components"
	@echo ""
	@echo "Environment variables (set in .env):"
	@echo "  CLUSTER_NAME            - Kind cluster name (default: kind-lab)"
	@echo "  LOCAL_DOMAIN            - Local domain (default: beavers.dev)"
	@echo ""
	@echo "  make help               - Show this help message." 