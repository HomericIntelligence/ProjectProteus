#!/usr/bin/env bash
# Offline regression test for issue #186: every checkbox in
# docs/audit-2026-04-28/remediation-plan.md must match its verified state.
#
# This test is HERMETIC — it makes NO network calls and does NOT shell out to
# `gh`. The expected state below is a committed fixture, ground-truthed against
# GitHub at authoring time (2026-06-20). It mirrors tests/dispatch-apply.test.sh
# (fully offline) and avoids the silent-failure no-op that a live-`gh` test with
# a skip-on-unauth branch would create (forbidden by docs/runbooks/no-silent-failures.md).
#
# RE-VERIFY: when an issue's GitHub state legitimately changes, run
#   gh issue view <N> --json state --jq .state
# then update both this fixture AND the plan doc in the same PR.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLAN="$REPO_ROOT/docs/audit-2026-04-28/remediation-plan.md"

[ -f "$PLAN" ] || { echo "FAIL: plan not found at $PLAN"; exit 1; }

# --- Committed fixture: the checkbox state each line MUST have. ---
# Per-issue lines (Wave 1 & 2): key=issue number, value=x (CLOSED) or " " (OPEN).
declare -A EXPECTED=(
  [88]=" " [85]="x" [86]="x" [87]="x" [94]=" " [95]=" " [99]="x" [100]="x" [102]=" "
  [83]=" " [84]="x" [82]=" " [97]=" " [93]=" " [92]="x"
)

fail=0

check_issue_box() {
  local num="$1" want="$2"
  local line
  line=$(grep -nE "^- \[[ x]\] #${num}\b" "$PLAN" || true)
  if [ -z "$line" ]; then
    echo "FAIL: no checkbox line found for #${num}"; fail=1; return
  fi
  if ! echo "$line" | grep -qE "^[0-9]+:- \[${want}\] #${num}\b"; then
    echo "FAIL: #${num} expected '[${want}]' but doc has: ${line#*:}"; fail=1
  fi
}

for num in "${!EXPECTED[@]}"; do
  check_issue_box "$num" "${EXPECTED[$num]}"
done

# --- Wave 3 PR-group lines: ticked iff ALL listed issues are CLOSED. ---
# Asserts exact expected box per group.
check_group() {
  local label="$1" want="$2" line
  line=$(grep -nE "^- \[[ x]\] PR-${label} " "$PLAN" || true)
  [ -n "$line" ] || { echo "FAIL: no line for PR-${label}"; fail=1; return; }
  echo "$line" | grep -qE "^[0-9]+:- \[${want}\] PR-${label} " \
    || { echo "FAIL: PR-${label} expected '[${want}]' got: ${line#*:}"; fail=1; }
}

check_group A x   # #96,107,108 all CLOSED
check_group B x   # #106 CLOSED
check_group C " " # #98 OPEN
check_group D x   # #109 CLOSED
check_group E " " # #101,#103 OPEN
check_group F x   # #110,111,119 CLOSED
check_group G x   # #117,116,114,121 CLOSED
check_group H x   # #113,115,120,118 CLOSED

if [ "$fail" -eq 0 ]; then
  echo "OK: all remediation-plan checkboxes match verified state"
else
  echo "::error::remediation-plan.md checkbox drift — update doc or fixture per RE-VERIFY note"
  exit 1
fi
