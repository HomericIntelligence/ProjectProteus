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
| Require review from code owners | **on** | #102 |
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
- Any future SAST / secrets-scan job once #85, #86 are fixed

A required status check that does not actually run on a PR will block
merges; whenever a check is renamed, this list must be updated in the
same PR.

## Why we are not enforcing this today

The defects in #95 (zero required approvals) and #102 (CODEOWNERS not
enforced in branch protection) are tracked separately. This document
exists so the next maintainer with admin access can apply the policy
in one pass without re-deriving it.

## Procedure to apply

1. Open repository Settings → Branches → Branch protection rules.
2. Add or edit the rule for `main` to match the table above.
3. Verify by issuing a no-op PR from a fork; it must require a review
   and a green status check before the **Merge** button enables.
4. Mark #41 / #95 / #102 / #94 closed as appropriate.

## See also

- `docs/milestones.md` — milestone targeting this change set
- `CLAUDE.md` "Known Critical Defects"
- `AGENTS.md` — cross-repo guarantees that depend on this ruleset
