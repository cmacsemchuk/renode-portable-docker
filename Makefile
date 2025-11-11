# Makefile for multi-architecture Renode Docker builds
# Simple, robust, CI/CD compatible

# -------------------------------------------------------------------
# Configuration (override via env or CLI, e.g.:
#   RENODE_VERSION=1.16.0+2025... make build
#   REGISTRY=localhost:5000 IMAGE_NAME=renode make build-multi
# -------------------------------------------------------------------
IMAGE_NAME      ?= renode
REGISTRY        ?=        # empty by default; required only for build-multi
RENODE_VERSION  ?= latest
BUILDER_NAME    ?= renode-multiarch-builder

# -------------------------------------------------------------------
# Host platform detection
# -------------------------------------------------------------------
HOST_ARCH := $(shell uname -m)

ifeq ($(HOST_ARCH),x86_64)
  NATIVE_PLATFORM := linux/amd64
else ifeq ($(HOST_ARCH),amd64)
  NATIVE_PLATFORM := linux/amd64
else ifeq ($(HOST_ARCH),arm64)
  NATIVE_PLATFORM := linux/arm64
else ifeq ($(HOST_ARCH),aarch64)
  NATIVE_PLATFORM := linux/arm64
else
  $(warning Unknown host architecture '$(HOST_ARCH)', defaulting to linux/amd64)
  NATIVE_PLATFORM := linux/amd64
endif

# -------------------------------------------------------------------
# Utility targets & helpers
# -------------------------------------------------------------------
.PHONY: help setup build build-multi clean registry-up registry-down \
        guard-REGISTRY

# Guard macro: ensure a variable is set for selected targets
guard-%:
	@if [ -z "$($*)" ]; then \
		echo "Error: $* is not set."; \
		echo "       Set $* when invoking make, for example:"; \
		echo "         $*=localhost:5000 make $@"; \
		exit 1; \
	fi

help: ## Show available commands
	@echo "Renode Multi-Architecture Docker Build"
	@echo
	@echo "Configuration:"
	@echo "  IMAGE_NAME      = $(IMAGE_NAME)"
	@echo "  REGISTRY        = $(REGISTRY)"
	@echo "  RENODE_VERSION  = $(RENODE_VERSION)"
	@echo "  Native platform = $(NATIVE_PLATFORM)"
	@echo
	@echo "Commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

# -------------------------------------------------------------------
# Buildx / registry helpers
# -------------------------------------------------------------------

setup: ## Setup Docker Buildx (binfmt + builder)
	@echo "Setting up Docker Buildx..."
	@docker run --privileged --rm tonistiigi/binfmt --install all
	@docker buildx inspect $(BUILDER_NAME) >/dev/null 2>&1 || \
		docker buildx create --name $(BUILDER_NAME) --driver docker-container --bootstrap --use
	@docker buildx use $(BUILDER_NAME)
	@echo "Buildx ready"

registry-up: ## Start local test registry on localhost:5000 (optional)
	@docker ps --format '{{.Names}}' | grep -q '^registry$$' || \
		docker run -d -p 5000:5000 --name registry registry:2
	@echo "Local registry running at localhost:5000"

registry-down: ## Stop and remove local test registry
	-@docker rm -f registry 2>/dev/null || true
	@echo "Local registry stopped"

# -------------------------------------------------------------------
# Build targets
# -------------------------------------------------------------------

build: setup ## Build for native platform and load into local Docker
	@echo "Building $(IMAGE_NAME):$(RENODE_VERSION) for $(NATIVE_PLATFORM)..."
	docker buildx build \
		--platform $(NATIVE_PLATFORM) \
		--build-arg RENODE_VERSION=$(RENODE_VERSION) \
		-t $(IMAGE_NAME):$(RENODE_VERSION) \
		-t $(IMAGE_NAME):latest \
		--load \
		.
	@echo "Build complete: $(IMAGE_NAME):$(RENODE_VERSION)"

build-multi: setup guard-REGISTRY ## Build for both AMD64 and ARM64 and push to a registry
	@echo "Building multi-arch $(IMAGE_NAME):$(RENODE_VERSION) for registry $(REGISTRY)..."
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg RENODE_VERSION=$(RENODE_VERSION) \
		-t $(REGISTRY)/$(IMAGE_NAME):$(RENODE_VERSION) \
		-t $(REGISTRY)/$(IMAGE_NAME):latest \
		--push \
		.
	@echo "✓ Multi-arch build pushed to $(REGISTRY)/$(IMAGE_NAME):$(RENODE_VERSION)"

clean: ## Remove local images
	@echo "Cleaning up..."
	-@docker rmi $(IMAGE_NAME):$(RENODE_VERSION) $(IMAGE_NAME):latest 2>/dev/null || true
	@echo "Cleaned"
