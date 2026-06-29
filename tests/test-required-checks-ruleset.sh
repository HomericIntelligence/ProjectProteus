#!/usr/bin/env bash
# Regression test for issue #94 (audit §6).
# Asserts the homeric-main-baseline ruleset's required contexts cover
# every job in _required.yml (modulo an explicit allowlist), that the
# `lint` job covers TypeScript via `tsc --noEmit`, and that the
# verify-issue-92-invariants.sh static check is still invoked.
set -euo pipefail

cd "$(dirname "$0")/.."
req=".github/workflows/_required.yml"

# (a) lint job must run tsc --noEmit (issue #94 acceptance).
if ! grep -qE 'tsc --noEmit' "$req"; then
  echo "FAIL[#94 a]: $req does not invoke 'tsc --noEmit'" >&2
  exit 1
fi

# (b) issue-92 invariants must still be invoked from _required.yml.
if ! grep -qE 'verify-issue-92-invariants\.sh' "$req"; then
  echo "FAIL[#94 b]: $req does not invoke verify-issue-92-invariants.sh" >&2
  exit 1
fi

# (c) Every job in _required.yml that runs on PRs must be in the
# ruleset's required-context list. Skip this check when GH_TOKEN is
# unset (local dev / forks); the GitHub API check then runs only in CI.
if [[ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]]; then
  jobs=$(grep -nE "^  [a-z][a-z/_-]+:$" "$req" | awk -F: '{print $3}' | tr -d ' ')
  # Map bash job IDs to their `name:` (slash-form) where applicable.
  declare -A name_of
  while read -r jobid; do
    name=$(awk -v j="$jobid" '
      $1=="  "j":" {found=1; next}
      found && /^    name:/ {sub(/^    name:[ ]*/,""); print; exit}
    ' "$req")
    name_of["$jobid"]="${name:-$jobid}"
  done <<<"$jobs"

  contexts=$(gh api \
    repos/HomericIntelligence/ProjectProteus/rulesets/15556490 \
    --jq '.rules[]|select(.type=="required_status_checks")|.parameters.required_status_checks[].context')

  missing=0
  for jobid in $jobs; do
    ctx="${name_of[$jobid]}"
    if ! grep -qxF "$ctx" <<<"$contexts"; then
      echo "FAIL[#94 c]: job '$ctx' is in $req but not in ruleset" >&2
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]] || exit 1
fi

echo "OK: required-checks ruleset matches _required.yml"
