# Branch Protection Policy

This document captures the **target** branch protection ruleset for
ProjectProteus's default branch (`main`). The ruleset is configured in
the GitHub UI / API by a repository admin; this file is the
human-readable source of truth and is updated in a PR before any UI
change.

## Why this matters

ProjectProteus is the CI/CD hub for the entire HomericIntelligence
ecosystem. A regression merged directly to `main` here can fan out to
AchaeanFleet image pushes, Myrmidons applies, and downstream agent
provisioning. Branch protection is the last guardrail.

## Target ruleset for `main`

| Setting | Target value | Tracked by |
|---|---|---|
| Restrict deletions | **on** | — |
| Restrict pushes (no force-pushes, no direct commits) | **on** | — |
| Require pull request before merging | **on** | — |
| Required approving review count | **1** (minimum) | #95 (enforced) |
| Dismiss stale approvals on new commits | **on** | — |
| Require review from code owners | **on** | #102 (enforced via API; CODEOWNERS coverage audit remains open) |
| Require status checks to pass | **on** | — |
| Required status checks | see below | #94 |
| Require branches to be up to date before merging | **on** | — |
| Require signed commits | **off** (under review) | — |
| Allowed merge methods | **squash only** | — |

### Required status checks

The following CI checks (from `.github/workflows/_required.yml` and `ci.yml`)
are the authoritative required set. Names match the workflow job `name:` field,
which is what GitHub uses for protection contexts:

- `lint` (shellcheck + yamllint + mypy)
- `Lint Shell Scripts` (ci.yml)
- `TypeScript Type Check` (ci.yml)
- `forbid-suppressions` (no-silent-failures guard)
- `unit-tests` (placeholder; to be replaced — #88)
- `integration-tests` (placeholder; to be expanded — #89)
- `schema-validation` (YAML pipeline config validation)
- `markdownlint` (documentation lint)
- `pixi-check` (pixi lock file consistency)
- `justfile-check` (justfile validation)
- `symlink-check` (verify all symlinks resolve)
- `build` (dagger build test)
- `security/secrets-scan` (gitleaks)
- `security/dependency-scan` (dependency audit)
- `branch-protection-test` (offline branch protection verification)

## Enforcement

The ruleset above is the **literal** body of `.github/branch-protection.main.json`.
It is applied automatically by `.github/workflows/apply-branch-protection.yml`
on every push to `main` that modifies the JSON file, using the admin-scoped
`BRANCH_PROTECTION_PAT` repository secret.

Manual operations (admin token required):

- Apply / re-apply: `GITHUB_TOKEN=<admin-pat> just apply-branch-protection`
- Detect drift:    `GITHUB_TOKEN=<admin-pat> just verify-branch-protection`

Offline regression coverage runs on every PR via `_required.yml` →
`branch-protection-test`; no token is required.

## See also

- `docs/milestones.md` — milestone targeting this change set
- `CLAUDE.md` "Known Critical Defects"
- `AGENTS.md` — cross-repo guarantees that depend on this ruleset
