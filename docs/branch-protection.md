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
| Required approving review count | **1** (minimum) | #95 |
| Dismiss stale approvals on new commits | **on** | — |
| Require review from code owners | **on** | #102 (applied via scripts/branch-protection-apply.sh) |
| Require status checks to pass | **on** | — |
| Required status checks | see below | #94 |
| Require branches to be up to date before merging | **on** | — |
| Require signed commits | **off** (under review) | — |
| Allowed merge methods | **squash only** | — |

### Required status checks

The following CI checks (from `.github/workflows/_required.yml`,
`ci.yml`, `cross-repo-dispatch.yml`, and `promote.yml`) are the
authoritative required set:

- `lint-scripts` (CI / shellcheck)
- `typecheck` (CI / `tsc --noEmit`)
- `forbid-suppressions` (no-silent-failures guard)
- `unit-tests` (YAML schema validation; to be replaced by real tests — #88)
- `integration-tests` (cross-config reference check; to be expanded — #89)
- `markdownlint` (docs lint)
- `security/npm-audit` (npm audit for known CVEs — #23)
- `security/secrets-scan` (Gitleaks SARIF upload + PR gating — #23, #86)
- `CodeQL / javascript-typescript` (SAST for TypeScript — #23)

A required status check that does not actually run on a PR will block
merges; whenever a check is renamed, this list must be updated in the
same PR.

## Why we are not enforcing this today

The defects in #95 (zero required approvals) and #102 (CODEOWNERS not
enforced in branch protection) are tracked separately. This document
exists so the next maintainer with admin access can apply the policy
in one pass without re-deriving it.

## Procedure to apply

The repo-level apply is scripted and idempotent:

1. `gh auth status` — confirm authentication has admin scope on the repo.
2. `just branch-protection-dry-run` — prints the merged payload **without
   PUT-ing it**. Review that `required_status_checks.contexts` lists the
   expected checks from #94, `required_approving_review_count` matches #95,
   and `restrictions` (if non-null) lists the expected users/teams/apps.
3. `just branch-protection-apply` — performs read-modify-write: every sibling
   field on `branches/main/protection` is round-tripped verbatim; only
   `require_code_owner_reviews` is mutated to `true`. Safe to re-run.
4. Verify:
   `gh api repos/HomericIntelligence/ProjectProteus/branches/main/protection --jq '.required_pull_request_reviews.require_code_owner_reviews'`
   prints `true`.
5. Close #102 once step 4 returns `true`.

The script uses `gh api -i` to parse HTTP status lines from stdout (a stable
contract across `gh` versions), so 404 (no existing protection) is handled by
creating minimal protection, while 401/403 (insufficient scope) fail fast with
an explicit error.

## See also

- `docs/milestones.md` — milestone targeting this change set
- `CLAUDE.md` "Known Critical Defects"
- `AGENTS.md` — cross-repo guarantees that depend on this ruleset
