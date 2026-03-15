# ===========================
# ProjectProteus — justfile
# CI/CD pipeline automation hub
# ===========================

REGISTRY := env_var_or_default("REGISTRY", "ghcr.io/homeric-intelligence")
IMAGE_TAG := env_var_or_default("IMAGE_TAG", "latest")
GITHUB_TOKEN := env_var_or_default("GITHUB_TOKEN", "")
MYRMIDONS_REPO := env_var_or_default("MYRMIDONS_REPO", "HomericIntelligence/Myrmidons")

# ===========================
# Default
# ===========================

# List all available recipes
default:
    @just --list

# ===========================
# Core Pipeline
# ===========================

# Build an OCI image using Dagger
build NAME:
    dagger call build --context . --name {{NAME}} --tag {{IMAGE_TAG}} --registry {{REGISTRY}}

# Run tests for a given repo using Dagger
test NAME:
    dagger call test --source . --command "just test"

# Full pipeline: build → test → promote → dispatch
pipeline NAME: (build NAME) (test NAME)
    just promote {{REGISTRY}}/{{NAME}}:{{IMAGE_TAG}}-staging {{REGISTRY}}/{{NAME}}:{{IMAGE_TAG}}
    just dispatch-apply hermes

# ===========================
# Promotion
# ===========================

# Promote (copy) an image from source registry to destination using skopeo
promote SRC DEST:
    ./scripts/promote-image.sh "{{SRC}}" "{{DEST}}"

# ===========================
# Dispatch
# ===========================

# Send repository_dispatch to trigger Myrmidons apply on HOST
dispatch-apply HOST:
    GITHUB_TOKEN={{GITHUB_TOKEN}} MYRMIDONS_REPO={{MYRMIDONS_REPO}} ./scripts/dispatch-apply.sh {{HOST}}

# ===========================
# Quality
# ===========================

# Run lint checks via Dagger
lint:
    dagger call lint --source .

# Validate all pipeline configs in configs/pipelines/
validate:
    @echo "Validating pipeline configs..."
    @for f in configs/pipelines/*.yaml; do \
        echo "  Checking $$f..."; \
        python3 -c "import yaml, sys; yaml.safe_load(open('$$f'))" && echo "  OK: $$f" || (echo "  FAIL: $$f" && exit 1); \
    done
    @echo "All pipeline configs valid."
