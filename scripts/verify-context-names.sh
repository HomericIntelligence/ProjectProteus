#!/usr/bin/env bash
# verify-context-names.sh — Assert every required-status-check context in
# .github/branch-protection.main.json corresponds to an actual workflow
# job `name:` field (with the codeql matrix expanded). Refs #95.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Collect all job names from the workflows. Job `name:` fields are top-level
# inside a job and indented exactly 4 spaces (yaml convention used across this
# repo's workflows — see _required.yml:18, ci.yml:27).
mapfile -t NAMES < <(
  grep -hE "^    name: " \
      "$ROOT/.github/workflows/_required.yml" \
      "$ROOT/.github/workflows/ci.yml" \
    | sed -E 's/^    name: "?(.*[^"])"?$/\1/'
)

# The NAMES array already contains all job names from the actual workflows.
EXPANDED=("${NAMES[@]}")

# Read JSON contexts and assert each is present.
mapfile -t CONTEXTS < <(jq -r '.required_status_checks.contexts[]' "$ROOT/.github/branch-protection.main.json")
missing=0
for ctx in "${CONTEXTS[@]}"; do
  found=0
  for n in "${EXPANDED[@]}"; do
    if [[ "$ctx" == "$n" ]]; then found=1; break; fi
  done
  if [[ "$found" -eq 0 ]]; then
    echo "Error: context '$ctx' has no matching workflow job name." >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo "Error: branch-protection.main.json references unknown job names." >&2
  exit 1
fi
echo "All ${#CONTEXTS[@]} contexts map to real workflow job names."
