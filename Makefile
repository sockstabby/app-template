# Local dev loop on kind. Requires: docker, kind, kubectl, helm (see platform/.tool-versions).
APP_NAME      ?= app-template
CLUSTER       ?= $(APP_NAME)
NAMESPACE     ?= default
# kind v0.33.0 node image (digest from the kind release notes, verified 2026-11-09)
KIND_IMAGE    ?= kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5
IMAGE         ?= $(APP_NAME):local
APP_VERSION   ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo local)
LOCAL_PORT    ?= 18080
KUBE_CONTEXT  := kind-$(CLUSTER)

.PHONY: help venv test lint kind-up build deploy-local smoke kind-down all

help: ## Show targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

venv: ## Create .venv with dev deps
	python3 -m venv .venv && .venv/bin/pip install -q -r app/requirements-dev.txt

test: ## Run unit tests
	.venv/bin/python -m pytest -q app/tests

lint: ## helm lint the chart with every values file
	@for f in local debug prod; do helm lint chart -f chart/values-$$f.yaml || exit 1; done

kind-up: ## Create the local kind cluster (idempotent)
	@kind get clusters 2>/dev/null | grep -qx $(CLUSTER) || kind create cluster --name $(CLUSTER) --image $(KIND_IMAGE) --wait 120s

build: ## Build the image and load it into kind
	docker build --build-arg APP_VERSION=$(APP_VERSION) -t $(IMAGE) .
	kind load docker-image $(IMAGE) --name $(CLUSTER)

deploy-local: ## helm upgrade --install with values-local.yaml
	helm upgrade --install $(APP_NAME) ./chart --kube-context $(KUBE_CONTEXT) -n $(NAMESPACE) \
	  -f chart/values-local.yaml --set image.tag=local --set-string podAnnotations.build=$(APP_VERSION)-$(shell date +%s) \
	  --wait --timeout 120s
	kubectl --context $(KUBE_CONTEXT) -n $(NAMESPACE) rollout status deploy/$(APP_NAME) --timeout=120s

smoke: ## Port-forward and curl /healthz (expects 200)
	@kubectl --context $(KUBE_CONTEXT) -n $(NAMESPACE) port-forward svc/$(APP_NAME) $(LOCAL_PORT):80 >/dev/null 2>&1 & PF=$$!; \
	trap "kill $$PF 2>/dev/null" EXIT; \
	for i in $$(seq 1 20); do curl -sf -o /dev/null http://localhost:$(LOCAL_PORT)/healthz && break; sleep 1; done; \
	code=$$(curl -s -o /dev/null -w '%{http_code}' http://localhost:$(LOCAL_PORT)/healthz); \
	echo "/healthz -> $$code"; curl -s http://localhost:$(LOCAL_PORT)/version; echo; \
	test "$$code" = 200

kind-down: ## Delete the local kind cluster
	kind delete cluster --name $(CLUSTER)

all: kind-up build deploy-local smoke ## Full local loop
