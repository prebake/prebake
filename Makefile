# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0

.PHONY: help setup render install uninstall kind-create kind-delete

help:
	@echo "Prebake - Developer Platform for Kubernetes"
	@echo ""
	@echo "Available targets:"
	@echo "  setup          Setup values files (cluster config)"
	@echo "  render         Render all Helm charts to _rendered/ directory"
	@echo "  install        Install all charts to current kubectl context"
	@echo "  uninstall      Uninstall all charts from current kubectl context"
	@echo "  kind-create    Create a local Kind cluster for testing"
	@echo "  kind-context   Configure kubectl to use the Kind cluster context"
	@echo "  kind-delete    Delete the local Kind cluster"
	@echo "  rbac-tests     Run RBAC configuration tests"
	@echo ""
	@echo "Example:"
	@echo "  make setup DOMAIN=local.dev"
	@echo "  make setup DOMAIN=example.com TYPE=eks"
	@echo "  make kind-create"
	@echo "  make kind-context"
	@echo "  make install"
	@echo "  make kind-delete"
	

setup:
ifndef DOMAIN
	@echo "Error: DOMAIN is required"
	@echo "Usage: make setup DOMAIN=<domain> [TYPE=<cluster-type>]"
	@exit 1
endif
ifdef TYPE
	@./scripts/setup.sh -d $(DOMAIN) -t $(TYPE)
else
	@./scripts/setup.sh -d $(DOMAIN)
endif

render:
	@./scripts/render.sh $(CHART)

install:
	@./scripts/install.sh $(CHART)

uninstall:
	@./scripts/uninstall.sh $(CHART)

kind-create:
	kind create cluster --config kind.yaml

kind-context:
	kubectl config use-context kind-prebake

kind-delete:
	kind delete cluster --name prebake

rbac-tests:
	@echo "Running RBAC tests..."
	@cd apps/rbac && ./run-tests.sh
