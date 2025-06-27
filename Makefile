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
.PHONY: up start down clean deps configure-domain install-jh

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

install-jh:
	@echo "--> 📓 Installing JupyterHub..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/install-jupyterhub.sh

# --- ArgoCD Targets ---
.PHONY: install-argocd setup-complete teardown-complete

install-argocd:
	@echo "--> 🔄 Installing ArgoCD GitOps platform..."
	@LOCAL_DOMAIN=$(LOCAL_DOMAIN) ./scripts/install-argocd.sh

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
	@echo "ArgoCD:"
	@echo "  make install-argocd     - Install ArgoCD GitOps platform"
	@echo "  make setup-complete     - Complete setup: cluster + ArgoCD"
	@echo "  make teardown-complete  - Complete teardown of all components"
	@echo ""
	@echo "JupyterHub:"
	@echo "  make install-jh         - Install JupyterHub"
	@echo ""
	@echo "Environment variables (set in .env):"
	@echo "  CLUSTER_NAME            - Kind cluster name (default: kind-lab)"
	@echo "  LOCAL_DOMAIN            - Local domain (default: beavers.dev)"
	@echo ""
	@echo "  make help               - Show this help message." 