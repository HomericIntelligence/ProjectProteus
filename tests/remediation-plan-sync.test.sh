#!/usr/bin/env bash
# Regression guard for issue #183: every tracked checkbox in
# docs/audit-2026-04-28/remediation-plan.md must match the expected state
# below. Deterministic and offline — no GitHub API, no auth, no SKIP path.
#
# To update after an issue closes: tick the box in the plan AND flip the
# matching entry here. The test enforces that the two stay in sync.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLAN="$REPO_ROOT/docs/audit-2026-04-28/remediation-plan.md"

[ -f "$PLAN" ] || { echo "FAIL: plan not found: $PLAN"; exit 1; }

# Expected checkbox char per tracked line, keyed by the line's stable token
# (the leading '#NNN' for issue rows, or 'PR-X' / phrase for Wave-3 / closeout
# rows). 'x' = must be [x]; ' ' = must be [ ].
# Bundle rows (PR-C, PR-E) are ' ' because the PR is unmerged even though some
# child issues are closed — this is intentional and must NOT fail.
declare -A EXPECT=(
  # Wave 1
  ["#88"]=" " ["#85"]="x" ["#86"]="x" ["#87"]="x" ["#94"]=" " ["#95"]=" "
  ["#99"]="x" ["#100"]="x" ["#102"]=" "
  # Wave 2
  ["#83"]=" " ["#84"]="x" ["#82"]=" " ["#97"]=" " ["#93"]=" " ["#92"]="x"
  # Wave 3 — PR bundles keyed by PR id; closeout rows by phrase
  ["PR-A"]="x" ["PR-B"]="x" ["PR-C"]=" " ["PR-D"]="x" ["PR-E"]=" "
  ["PR-F"]="x" ["PR-G"]="x" ["PR-H"]="x"
  ["Re-audit"]=" " ["Close #81"]=" "
)

# Derive the stable key for a checkbox line's text (everything after '] ').
key_for() {
  local text="$1"
  case "$text" in
    "PR-A"*) echo "PR-A" ;;  "PR-B"*) echo "PR-B" ;;  "PR-C"*) echo "PR-C" ;;
    "PR-D"*) echo "PR-D" ;;  "PR-E"*) echo "PR-E" ;;  "PR-F"*) echo "PR-F" ;;
    "PR-G"*) echo "PR-G" ;;  "PR-H"*) echo "PR-H" ;;
    "Re-audit"*) echo "Re-audit" ;;
    "Close #81"*) echo "Close #81" ;;
    "#"*) echo "${text%% *}" ;;          # leading '#NNN' token
    *) echo "" ;;                         # untracked checkbox line
  esac
}

fail=0
declare -A SEEN=()

# Parse every checkbox bullet: capture the box char and the trailing text.
while IFS= read -r line; do
  # matches '- [x] text' or '- [ ] text'
  if [[ "$line" =~ ^-\ \[([ x])\]\ (.*)$ ]]; then
    box="${BASH_REMATCH[1]}"
    text="${BASH_REMATCH[2]}"
    k="$(key_for "$text")"
    [ -z "$k" ] && continue                 # non-tracked checkbox (none expected)
    SEEN["$k"]=1
    exp="${EXPECT[$k]:-__MISSING__}"
    if [ "$exp" = "__MISSING__" ]; then
      echo "FAIL: untracked checkbox line '$k' — add it to EXPECT in this test"
      fail=1
    elif [ "$box" != "$exp" ]; then
      echo "FAIL: '$k' has [${box}] but expected [${exp}] — plan out of sync with issue state (#183)"
      fail=1
    fi
  fi
done < "$PLAN"

# Every expected key must actually appear in the plan.
for k in "${!EXPECT[@]}"; do
  if [ -z "${SEEN[$k]:-}" ]; then
    echo "FAIL: expected tracked line '$k' not found in plan"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "remediation-plan.md checkbox state is out of sync (see #183)."
  exit 1
fi
echo "OK: all ${#EXPECT[@]} tracked checkboxes match expected state."
