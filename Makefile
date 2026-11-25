SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

TF_DIR      := terraform/environments/local
CLUSTER     := observability-lab
IMAGE       := demo-api:local
export KUBECONFIG := $(CURDIR)/$(TF_DIR)/kubeconfig

##@ Lifecycle

.PHONY: up
up: check-tools infra image load deploy urls ## Create cluster + monitoring, build and deploy the app

.PHONY: infra
infra: ## terraform apply: kind cluster, kube-prometheus-stack, metrics-server
	terraform -chdir=$(TF_DIR) init -input=false
	terraform -chdir=$(TF_DIR) apply -input=false -auto-approve

.PHONY: image
image: ## Build the demo-api container image
	docker build -t $(IMAGE) --build-arg APP_VERSION=$$(git rev-parse --short HEAD 2>/dev/null || echo dev) app

.PHONY: load
load: ## Load the image into the kind nodes (no registry needed)
	kind load docker-image $(IMAGE) --name $(CLUSTER)

.PHONY: deploy
deploy: ## Apply the Kubernetes manifests and wait for rollout
	kubectl apply -k k8s/overlays/local
	kubectl -n demo rollout restart deploy/demo-api
	kubectl -n demo rollout status deploy/demo-api --timeout=180s

.PHONY: down
down: ## Destroy everything
	terraform -chdir=$(TF_DIR) destroy -input=false -auto-approve

##@ Observe

.PHONY: urls
urls: ## Print UI URLs and the Grafana password
	@echo "Grafana:    http://localhost:3000  (admin / $$(terraform -chdir=$(TF_DIR) output -raw grafana_admin_password))"
	@echo "Prometheus: http://localhost:9090"
	@echo "Alerts:     http://localhost:9090/alerts"
	@echo "kubectl:    export KUBECONFIG=$(KUBECONFIG)"

.PHONY: status
status: ## Show workloads, HPA and Prometheus targets for the app
	kubectl -n demo get deploy,pods,hpa,pdb -o wide
	@curl -fsS 'http://localhost:9090/api/v1/query' --data-urlencode 'query=up{namespace="demo"}' \
	  | python3 -c 'import sys,json; [print(r["metric"]["pod"], "up=" + r["value"][1]) for r in json.load(sys.stdin)["data"]["result"]]'

.PHONY: app-forward
app-forward: ## Port-forward the app to http://localhost:8080
	kubectl -n demo port-forward svc/demo-api 8080:80

.PHONY: chaos
chaos: ## Make the app fail 30% of requests: DemoApiHighErrorRate fires in ~5 minutes
	kubectl -n demo set env deploy/demo-api ERROR_RATE=0.3 MAX_LATENCY_MS=900

.PHONY: calm
calm: ## Restore normal error rate and latency
	kubectl -n demo set env deploy/demo-api ERROR_RATE=0.02 MAX_LATENCY_MS=250

##@ Quality

.PHONY: test
test: test-app test-terraform test-alerts ## Run all offline tests

.PHONY: test-app
test-app: ## Lint and unit-test the app
	cd app && ruff check . && ruff format --check . && pytest --cov=demo_api --cov-fail-under=90

.PHONY: test-terraform
test-terraform: ## fmt, validate and `terraform test` every module, then tflint
	terraform fmt -check -recursive terraform
	@for d in terraform/modules/* $(TF_DIR); do \
	  echo "==> $$d"; \
	  terraform -chdir=$$d init -backend=false -input=false >/dev/null; \
	  terraform -chdir=$$d validate; \
	  if [[ $$d == terraform/modules/* ]]; then terraform -chdir=$$d test; fi; \
	done
	tflint --init && tflint --recursive --config "$(CURDIR)/.tflint.hcl"

.PHONY: test-alerts
test-alerts: ## promtool check + unit tests for the alerting rules
	yq 'select(.kind == "PrometheusRule") | .spec' k8s/base/monitoring.yaml > k8s/tests/.generated-rules.yaml
	promtool check rules k8s/tests/.generated-rules.yaml
	promtool test rules k8s/tests/alerts.test.yaml

.PHONY: validate-manifests
validate-manifests: ## Render kustomize and validate against Kubernetes + CRD schemas
	kustomize build k8s/overlays/local | kubeconform -strict -summary \
	  -schema-location default \
	  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

##@ Helpers

.PHONY: check-tools
check-tools: ## Verify required CLIs are installed
	@for t in docker terraform kind kubectl; do \
	  command -v $$t >/dev/null || { echo "missing: $$t"; exit 1; }; done
	@docker info >/dev/null 2>&1 || { echo "Docker daemon is not running"; exit 1; }
	@echo "all tools present"

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n"} \
	  /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
