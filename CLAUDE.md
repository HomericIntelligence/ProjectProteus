# ProjectProteus — CLAUDE.md

## Project Overview

ProjectProteus is the CI/CD pipeline automation hub for the HomericIntelligence ecosystem. It centralizes all pipeline logic using Dagger (TypeScript SDK), manages OCI image builds, runs test suites, promotes images via Skopeo, and orchestrates cross-repo GitHub Actions dispatch events.

- Images are built and pushed to registries managed by **AchaeanFleet**.
- Deployments are triggered in **Myrmidons** via `repository_dispatch`.
- All pipeline logic is reusable across HomericIntelligence repos via Dagger modules.

## Key Principles

- Pipelines are code: all logic lives in `dagger/src/index.ts`, not in sprawling shell scripts.
- Cross-repo coordination uses GitHub's `repository_dispatch` API — no polling.
- Image promotion (staging → production) is explicit and auditable via `scripts/promote-image.sh`.
- Environment management uses pixi; task running uses justfile. Never use Makefiles.
- New features go into new repos; do not modify existing HomericIntelligence repos.

## Repository Structure

```
ProjectProteus/
├── dagger/
│   ├── src/
│   │   └── index.ts        # Dagger TypeScript module (Proteus class)
│   ├── package.json
│   └── tsconfig.json
├── scripts/
│   ├── promote-image.sh    # skopeo copy wrapper
│   ├── dispatch-apply.sh   # GitHub API repository_dispatch sender
│   └── check-symlinks.sh   # verify all repo symlinks resolve (run in CI symlink-check job)
├── configs/
│   └── pipelines/
│       └── achaean-fleet.yaml  # Pipeline config for AchaeanFleet
├── .github/
│   └── workflows/
│       ├── ci.yml                   # Validate on push/PR
│       ├── cross-repo-dispatch.yml  # AchaeanFleet → Myrmidons bridge
│       └── promote.yml              # Manual promotion workflow
├── justfile
├── pixi.toml
├── CLAUDE.md
└── README.md
```

## Pipeline Architecture

### Dagger Module (`dagger/src/index.ts`)

The `Proteus` class exposes three core pipeline functions:

| Function | Description |
|----------|-------------|
| `build(context, name, tag)` | Builds OCI image from Dockerfile, returns digest |
| `test(source, command)` | Runs test command inside container, returns output |
| `lint(source)` | Runs lint checks, returns output |

Dagger calls are made via `dagger call <function> --<args>` from the justfile.

### Cross-Repo Dispatch Flow

1. AchaeanFleet pushes an image and sends `repository_dispatch` (type: `image-pushed`) to ProjectProteus.
2. `cross-repo-dispatch.yml` receives the event and calls `scripts/dispatch-apply.sh`.
3. `dispatch-apply.sh` sends a `repository_dispatch` (type: `agamemnon-apply`) to Myrmidons.
4. Myrmidons runs `just apply` on the target host.

### Image Promotion Flow

```
Build (dagger call build) → Test (dagger call test) → Promote (skopeo copy) → Dispatch apply
```

This full pipeline is invoked with `just pipeline NAME`.

## Known Critical Defects

The following defects are open and **load-bearing** — agents working in
this repo should know about them before changing behaviour in the
affected areas. Always check the linked issue for the current status
before assuming the defect is unfixed.

- **Cross-repo dispatch payload contract mismatch.** `cross-repo-dispatch.yml`
  reads `client_payload.host`, but no documented upstream emitter currently
  sends that field consistently. See #15, #84.
- **Build/promote tag arithmetic broken.** The build and promote scripts
  produce incorrect tags in edge cases (multi-arch, no-tag input). See
  #2, #83.
- **Pipeline YAML configs are not consumed.** `configs/pipelines/*.yaml`
  is parsed only by `just validate`; no production code reads it.
  See #1, #82.
- **CI unit/integration jobs run real tests (resolved by #5).** The
  `unit-tests` job runs Jest against `dagger/src/`; `integration-tests`
  runs bats against `scripts/`. The CI badge is now load-bearing.
  E2E coverage is opt-in via the `e2e` label or push-to-main.
- **GitHub Actions security gaps.** Gitleaks runs with
  `continue-on-error` (#86); Trivy runs with `exit-code: 0` (#85).
  Treat absence of a failure as inconclusive.
- **Branch protection partial.** PRs require zero reviews (#95); no
  CODEOWNERS enforcement (#102). See `docs/branch-protection.md` for
  the target state.

Agents must not silently work around these defects; instead, link the
relevant issue from any PR that touches the affected code.

## Development Guidelines

- All Dagger functions must be tested locally with `dagger call` before committing.
- Pipeline configs in `configs/pipelines/` must be valid YAML; `just validate` checks them.
- Scripts in `scripts/` must be executable and pass `shellcheck`.
- Keep the Dagger module typed — no `any` in TypeScript.
- Use `set -euo pipefail` in all bash scripts.

## Common Commands

```bash
# List all available tasks
just

# Build an OCI image
just build myapp

# Run tests
just test myapp

# Promote image from staging to production
just promote ghcr.io/homeric-intelligence/myapp:staging ghcr.io/homeric-intelligence/myapp:latest

# Trigger Myrmidons apply on a host
just dispatch-apply hermes

# Full pipeline
just pipeline myapp

# Lint check via Dagger
just lint

# Validate pipeline configs
just validate

# Enter pixi environment
pixi shell
```
