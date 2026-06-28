#!/usr/bin/env bash
# Tests for scripts/branch-protection-apply.sh (#102)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_GET="$REPO_ROOT/tests/fixtures/branch-protection-get.json"
FIXTURE_PUT="$REPO_ROOT/tests/fixtures/branch-protection-put.expected.json"

SHIM_DIR="$(mktemp -d)"
trap 'rm -rf "$SHIM_DIR"' EXIT

# make_shim mode capture
#   mode:    fresh | already-true | restrictions | http-404 | http-403
#   capture: path to write the PUT body to (unused for http-403, http-404 no-PUT runs)
make_shim() {
  local mode="$1" capture="$2"
  cat >"$SHIM_DIR/gh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
mode="$mode"
capture="$capture"
fixture_get="$FIXTURE_GET"

# Capture PUT body.
if [[ "\${1:-}" == "api" && "\${2:-}" == "-X" && "\${3:-}" == "PUT" ]]; then
  cat > "\$capture"
  exit 0
fi

# Final verification call: \`gh api ... --jq '...require_code_owner_reviews'\`.
if [[ "\$*" == *"--jq"* && "\$*" == *"require_code_owner_reviews"* ]]; then
  echo "true"; exit 0
fi

# Initial read: \`gh api -i repos/.../protection\`.
if [[ "\${1:-}" == "api" && "\${2:-}" == "-i" ]]; then
  case "\$mode" in
    http-404)
      printf 'HTTP/2.0 404 Not Found\r\nContent-Type: application/json\r\n\r\n{"message":"Branch not protected"}\n'
      exit 0 ;;
    http-403)
      printf 'HTTP/2.0 403 Forbidden\r\nContent-Type: application/json\r\n\r\n{"message":"Resource not accessible by integration"}\n'
      exit 0 ;;
    already-true)
      printf 'HTTP/2.0 200 OK\r\n\r\n'
      jq '.required_pull_request_reviews.require_code_owner_reviews = true' "\$fixture_get"
      exit 0 ;;
    restrictions|fresh)
      printf 'HTTP/2.0 200 OK\r\n\r\n'
      cat "\$fixture_get"
      exit 0 ;;
  esac
fi
echo "shim: unhandled args: \$*" >&2
exit 99
EOF
  chmod +x "$SHIM_DIR/gh"
}

# --- Case 1: fresh apply preserves sibling fields AND matches golden fixture ---
CAPTURE1="$SHIM_DIR/put1.json"
make_shim "fresh" "$CAPTURE1"
PATH="$SHIM_DIR:$PATH" "$REPO_ROOT/scripts/branch-protection-apply.sh" >/dev/null 2>&1

jq -e '.required_pull_request_reviews.require_code_owner_reviews == true' "$CAPTURE1" >/dev/null \
  || { echo "FAIL case1a: require_code_owner_reviews not true"; cat "$CAPTURE1"; exit 1; }
jq -e '.required_status_checks.contexts == ["lint-scripts","typecheck"]' "$CAPTURE1" >/dev/null \
  || { echo "FAIL case1b: contexts NOT preserved (regresses #94)"; cat "$CAPTURE1"; exit 1; }
jq -e '.required_status_checks.strict == true' "$CAPTURE1" >/dev/null \
  || { echo "FAIL case1c: strict NOT preserved"; cat "$CAPTURE1"; exit 1; }
jq -e '.required_pull_request_reviews.required_approving_review_count == 2' "$CAPTURE1" >/dev/null \
  || { echo "FAIL case1d: approving_review_count NOT preserved (regresses #95)"; cat "$CAPTURE1"; exit 1; }
jq -e '.enforce_admins == true' "$CAPTURE1" >/dev/null \
  || { echo "FAIL case1e: enforce_admins NOT preserved"; cat "$CAPTURE1"; exit 1; }
jq -e '.required_conversation_resolution == true' "$CAPTURE1" >/dev/null \
  || { echo "FAIL case1f: required_conversation_resolution NOT preserved"; cat "$CAPTURE1"; exit 1; }

# Golden-master diff — fails on ANY projection drift, not just the six fields above.
diff -u <(jq -S . "$FIXTURE_PUT") <(jq -S . "$CAPTURE1") \
  || { echo "FAIL case1-golden: PUT body drifted from fixture"; exit 1; }

# --- Case 2: idempotent re-run when already true ---
CAPTURE2="$SHIM_DIR/put2.json"
make_shim "already-true" "$CAPTURE2"
PATH="$SHIM_DIR:$PATH" "$REPO_ROOT/scripts/branch-protection-apply.sh" >/dev/null 2>&1
jq -e '.required_pull_request_reviews.require_code_owner_reviews == true' "$CAPTURE2" >/dev/null \
  || { echo "FAIL case2: idempotent re-run did not preserve true"; exit 1; }

# --- Case 3: DRY_RUN=1 routes payload to DRY_RUN_OUT, does NOT call PUT ---
CAPTURE3="$SHIM_DIR/put3.json"
DRY_OUT="$SHIM_DIR/dry-out.json"
make_shim "fresh" "$CAPTURE3"
PATH="$SHIM_DIR:$PATH" DRY_RUN=1 DRY_RUN_OUT="$DRY_OUT" \
  "$REPO_ROOT/scripts/branch-protection-apply.sh" >/dev/null 2>&1
[[ -f "$CAPTURE3" ]] && { echo "FAIL case3a: DRY_RUN=1 still called PUT"; exit 1; }
jq -e '.required_pull_request_reviews.require_code_owner_reviews == true' "$DRY_OUT" >/dev/null \
  || { echo "FAIL case3b: DRY_RUN_OUT did not contain target field"; cat "$DRY_OUT"; exit 1; }

# --- Case 4: restrictions path (R1 review's residual gap) ---
CAPTURE4="$SHIM_DIR/put4.json"
make_shim "restrictions" "$CAPTURE4"
PATH="$SHIM_DIR:$PATH" "$REPO_ROOT/scripts/branch-protection-apply.sh" >/dev/null 2>&1
jq -e '.restrictions.users == ["alice"]' "$CAPTURE4" >/dev/null \
  || { echo "FAIL case4a: restrictions.users NOT preserved (silent clear)"; cat "$CAPTURE4"; exit 1; }
jq -e '.restrictions.teams == ["core"]' "$CAPTURE4" >/dev/null \
  || { echo "FAIL case4b: restrictions.teams NOT preserved"; cat "$CAPTURE4"; exit 1; }
jq -e '.restrictions.apps == ["actions"]' "$CAPTURE4" >/dev/null \
  || { echo "FAIL case4c: restrictions.apps NOT preserved"; cat "$CAPTURE4"; exit 1; }

# --- Case 5: HTTP 404 triggers minimal payload, exit 0 ---
CAPTURE5="$SHIM_DIR/put5.json"
make_shim "http-404" "$CAPTURE5"
PATH="$SHIM_DIR:$PATH" "$REPO_ROOT/scripts/branch-protection-apply.sh" >/dev/null 2>&1
jq -e '.required_pull_request_reviews.require_code_owner_reviews == true' "$CAPTURE5" >/dev/null \
  || { echo "FAIL case5a: 404 path did not produce minimal payload with target field"; cat "$CAPTURE5"; exit 1; }
jq -e '.required_status_checks == null' "$CAPTURE5" >/dev/null \
  || { echo "FAIL case5b: 404 path should set required_status_checks=null"; cat "$CAPTURE5"; exit 1; }

# --- Case 6: HTTP 403 exits non-zero, no PUT ---
CAPTURE6="$SHIM_DIR/put6.json"
make_shim "http-403" "$CAPTURE6"
if PATH="$SHIM_DIR:$PATH" "$REPO_ROOT/scripts/branch-protection-apply.sh" >/dev/null 2>"$SHIM_DIR/err6"; then
  echo "FAIL case6a: HTTP 403 should exit non-zero"; exit 1
fi
[[ -f "$CAPTURE6" ]] && { echo "FAIL case6b: HTTP 403 must not call PUT"; exit 1; }
grep -q "HTTP 403" "$SHIM_DIR/err6" \
  || { echo "FAIL case6c: error message should mention HTTP 403"; cat "$SHIM_DIR/err6"; exit 1; }

echo "OK: 6 cases passed (preserve siblings + golden fixture, idempotent, dry-run-routed, restrictions, 404, 403)"
