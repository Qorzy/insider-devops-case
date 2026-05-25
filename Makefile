# insider-devops-case Makefile
# Reproducible local commands. Run `make help` for the list.

SHELL := /bin/bash
.DEFAULT_GOAL := help

# --- variables ---
IMAGE_NAME      ?= insider-case
IMAGE_TAG       ?= dev
GHCR_IMAGE      ?= ghcr.io/qorzy/insider-devops-case/insider-case
NAMESPACE_DEV   ?= insider-dev
NAMESPACE_PROD  ?= insider-prod
RELEASE_DEV     ?= app
RELEASE_PROD    ?= app-prod
CHART_PATH      := helm/insider-case

# --- help (default target) ---
.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ==========================================================
# Local development
# ==========================================================

.PHONY: venv
venv: ## Create Python virtualenv and install dev deps
	python3 -m venv .venv
	source .venv/bin/activate && pip install -r requirements-dev.txt

.PHONY: test
test: ## Run pytest
	source .venv/bin/activate && pytest -v

.PHONY: lint
lint: ## Run ruff + helm lint
	source .venv/bin/activate && ruff check .
	helm lint $(CHART_PATH)

# ==========================================================
# Docker (local)
# ==========================================================

.PHONY: docker-build
docker-build: ## Build the Docker image locally
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) \
		--build-arg BUILD_SHA=$$(git rev-parse HEAD) .

.PHONY: docker-run
docker-run: ## Run the image on localhost:8080
	docker run --rm -p 8080:8080 $(IMAGE_NAME):$(IMAGE_TAG)

# ==========================================================
# Minikube lifecycle
# ==========================================================

.PHONY: cluster-up
cluster-up: ## Start minikube with sane defaults and enable ingress
	minikube start --driver=docker --cpus=4 --memory=6g --kubernetes-version=v1.30.0
	minikube addons enable ingress
	@echo "Cluster ready. Minikube IP: $$(minikube ip)"

.PHONY: cluster-down
cluster-down: ## Stop minikube (preserves state)
	minikube stop

.PHONY: cluster-destroy
cluster-destroy: ## Delete minikube cluster
	minikube delete

.PHONY: image-load
image-load: docker-build ## Build and load the image into minikube's Docker
	@eval $$(minikube docker-env) && \
		docker build -t $(IMAGE_NAME):$(IMAGE_TAG) \
			--build-arg BUILD_SHA=$$(git rev-parse HEAD) .
	@echo "Image $(IMAGE_NAME):$(IMAGE_TAG) loaded into minikube"

# ==========================================================
# Helm deploy (the "auto-deploy on merge" equivalent, run locally)
# ==========================================================

.PHONY: deploy-dev
deploy-dev: ## Deploy/upgrade to the dev namespace
	helm upgrade --install $(RELEASE_DEV) $(CHART_PATH) \
		-f $(CHART_PATH)/values-dev.yaml \
		--set image.tag=$(IMAGE_TAG) \
		--namespace $(NAMESPACE_DEV) \
		--create-namespace \
		--wait --timeout 2m

.PHONY: deploy-prod
deploy-prod: ## Deploy/upgrade to the prod namespace
	helm upgrade --install $(RELEASE_PROD) $(CHART_PATH) \
		-f $(CHART_PATH)/values-prod.yaml \
		--set image.tag=$(IMAGE_TAG) \
		--namespace $(NAMESPACE_PROD) \
		--create-namespace \
		--wait --timeout 2m

.PHONY: deploy-ghcr
deploy-ghcr: ## Deploy the latest GHCR image to dev (post-merge workflow)
	@echo "Pulling latest from GHCR and deploying to $(NAMESPACE_DEV)..."
	@eval $$(minikube docker-env) && docker pull $(GHCR_IMAGE):latest
	helm upgrade --install $(RELEASE_DEV) $(CHART_PATH) \
		-f $(CHART_PATH)/values-dev.yaml \
		--set image.repository=$(GHCR_IMAGE) \
		--set image.tag=latest \
		--namespace $(NAMESPACE_DEV) \
		--wait --timeout 2m

.PHONY: rollback-dev
rollback-dev: ## Rollback the dev release to the previous revision
	helm rollback $(RELEASE_DEV) -n $(NAMESPACE_DEV) --wait

# ==========================================================
# Inspection
# ==========================================================

.PHONY: status
status: ## Show pods, services, ingress, and helm history for dev
	@echo "=== Pods ==="
	@kubectl get pods -n $(NAMESPACE_DEV)
	@echo
	@echo "=== Helm history ==="
	@helm history $(RELEASE_DEV) -n $(NAMESPACE_DEV)

.PHONY: logs
logs: ## Tail logs from the dev pods
	kubectl logs -n $(NAMESPACE_DEV) -l app.kubernetes.io/name=insider-case -f --tail=50

.PHONY: port-forward
port-forward: ## Port-forward dev service to localhost:8080
	kubectl port-forward -n $(NAMESPACE_DEV) svc/$(RELEASE_DEV)-insider-case 8080:80

# ==========================================================
# CI parity (run locally what CI runs)
# ==========================================================

.PHONY: ci-local
ci-local: lint test docker-build ## Run the CI checks locally
	@echo "All CI checks passed locally."

.PHONY: clean
clean: ## Remove venv and Python caches
	rm -rf .venv .pytest_cache __pycache__ */__pycache__ */*/__pycache__