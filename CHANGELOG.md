# Changelog

All notable changes to ProjectProteus will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial CI/CD pipeline hub scaffold with Dagger TypeScript SDK
- `Proteus` Dagger module with `build`, `test`, and `lint` pipeline functions
- Cross-repo dispatch workflow (`cross-repo-dispatch.yml`) bridging AchaeanFleet → Myrmidons
- Image promotion workflow (`promote.yml`) with manual trigger
- `scripts/promote-image.sh` — skopeo-based image promotion wrapper
- `scripts/dispatch-apply.sh` — GitHub API repository_dispatch sender
- Pipeline configuration schema in `configs/pipelines/`
- `justfile` task runner with `build`, `test`, `lint`, `validate`, `pipeline`, `promote`, and `dispatch-apply` recipes
- `pixi.toml` environment management
- LICENSE, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md
