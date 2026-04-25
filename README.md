# ProjectProteus

[![CI](https://github.com/HomericIntelligence/ProjectProteus/actions/workflows/ci.yml/badge.svg)](https://github.com/HomericIntelligence/ProjectProteus/actions/workflows/ci.yml)

CI/CD pipeline automation hub for the HomericIntelligence ecosystem.

## Purpose

ProjectProteus is the centralized pipeline orchestration layer for all HomericIntelligence services. It provides reusable Dagger modules for building OCI images, running test suites, and promoting images across registries. Cross-repo dispatch patterns ensure that image pushes from AchaeanFleet automatically trigger deployment workflows in Myrmidons.

## Architecture

### Dagger Modules

- **build** — Builds OCI images from Dockerfiles, returns image digest.
- **test** — Runs test suites inside containers, returns output.
- **promote** — Uses Skopeo to copy images between registries (staging → production).
- **lint** — Runs linting checks across source directories.

### Cross-Repo Dispatch Pattern

```
AchaeanFleet (image push)
    └─► ProjectProteus (cross-repo-dispatch.yml receives repository_dispatch)
            └─► Myrmidons (triggers apply via repository_dispatch)
```

AchaeanFleet sends a `repository_dispatch` event with type `image-pushed` to ProjectProteus. The `cross-repo-dispatch.yml` workflow picks this up and triggers a Myrmidons apply against the appropriate host.

## Quick Start

```bash
# Build an image
just build IMAGE_NAME

# Run tests
just test IMAGE_NAME

# Promote an image from staging to production
just promote ghcr.io/homeric-intelligence/myapp:staging ghcr.io/homeric-intelligence/myapp:latest

# Full pipeline: build → test → promote → dispatch
just pipeline IMAGE_NAME

# Trigger Myrmidons apply
just dispatch-apply hermes
```

## Integration Points

| Repo | Role |
|------|------|
| **AchaeanFleet** | Calls Proteus for image builds and promotion after each push |
| **Myrmidons** | Receives `repository_dispatch` on image push; runs `just apply` |
| **ProjectProteus** | Owns all shared pipeline logic, Dagger modules, and dispatch scripts |

## Repository Structure

```
ProjectProteus/
├── dagger/
│   └── src/
│       └── index.ts        # Dagger TypeScript pipeline module
├── scripts/
│   ├── promote-image.sh    # Skopeo image copy helper
│   └── dispatch-apply.sh   # GitHub API dispatch trigger
├── configs/
│   └── pipelines/
│       └── achaean-fleet.yaml  # Per-repo pipeline config
├── .github/
│   └── workflows/
│       ├── ci.yml                   # Validate pipeline configs on push/PR
│       ├── cross-repo-dispatch.yml  # Receives AchaeanFleet events, triggers Myrmidons
│       └── promote.yml              # Manual image promotion workflow
├── justfile
├── pixi.toml
├── CLAUDE.md
└── README.md
```

## Prerequisites

- [Dagger CLI](https://docs.dagger.io/install) installed
- [Skopeo](https://github.com/containers/skopeo) for image promotion
- `GITHUB_TOKEN` with `repo` scope for cross-repo dispatch
- [pixi](https://prefix.dev/) for environment management
