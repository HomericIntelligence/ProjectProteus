#!/usr/bin/env bash
# Tests for scripts/dispatch-apply.sh retry + dead-letter behaviour. Refs #98.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d -t proteus-retry.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT INT TERM

# Fast retries so the suite completes in <2s.
export DISPATCH_BASE_DELAY_MS=5
export DISPATCH_MAX_DELAY_MS=20
export DISPATCH_MAX_ATTEMPTS=3
export DISPATCH_DLQ_DIR="$TMP/dlq"
export GITHUB_TOKEN="fake"
export MYRMIDONS_REPO="HomericIntelligence/Myrmidons"

# --- shim factory: writes a curl shim that returns a programmable sequence.
_make_shim() {
  local dir="$1"; shift
  mkdir -p "$dir"
  : > "$dir/count"
  : > "$dir/delays"
  printf '0' > "$dir/last_ts_ms"
  printf '%s\n' "$@" > "$dir/codes"
  cat >"$dir/curl" <<'SHIM'
#!/usr/bin/env bash
# Reads the next code from ./codes and emits "\n<code>\n".
n=$(($(wc -l < "${SHIM_DIR}/count" 2>/dev/null || echo 0) + 1))
seq 1 "$n" > "${SHIM_DIR}/count"
code=$(sed -n "${n}p" "${SHIM_DIR}/codes")
[ -z "$code" ] && code=$(tail -n1 "${SHIM_DIR}/codes")
now_ms=$(($(date +%s%N) / 1000000))
prev=$(cat "${SHIM_DIR}/last_ts_ms" 2>/dev/null || echo 0)
[ "$prev" != 0 ] && echo $((now_ms - prev)) >> "${SHIM_DIR}/delays"
echo "$now_ms" > "${SHIM_DIR}/last_ts_ms"
printf '\n%s\n' "$code"
SHIM
  chmod +x "$dir/curl"
}

_run() {
  local dir="$1"; shift
  SHIM_DIR="$dir" PATH="$dir:$PATH" "$REPO_ROOT/scripts/dispatch-apply.sh" "$@"
}

# Case A: transient 503 then 204 → exit 0, exactly 2 curl calls.
A="$TMP/A"; _make_shim "$A" 503 204
_run "$A" hermes >/dev/null
[ "$(wc -l < "$A/count")" -eq 2 ] || { echo "FAIL A: expected 2 attempts"; exit 1; }

# Case B: exhausted retries → nonzero exit + DLQ file present with payload.
B="$TMP/B"; _make_shim "$B" 503 503 503
if _run "$B" hermes >/dev/null 2>&1; then echo "FAIL B: expected nonzero"; exit 1; fi
b_dlq=("$DISPATCH_DLQ_DIR"/*-hermes.json)
[ -f "${b_dlq[0]}" ] || { echo "FAIL B: no DLQ file"; exit 1; }
jq -e '.payload | fromjson | .client_payload.host == "hermes"' \
  "${b_dlq[0]}" >/dev/null \
  || { echo "FAIL B: DLQ payload host mismatch"; exit 1; }
rm -rf "$DISPATCH_DLQ_DIR"

# Case C: 401 → fail-fast, exactly 1 attempt.
C="$TMP/C"; _make_shim "$C" 401 401 401
if _run "$C" hermes >/dev/null 2>&1; then echo "FAIL C: expected nonzero"; exit 1; fi
[ "$(wc -l < "$C/count")" -eq 1 ] || { echo "FAIL C: expected 1 attempt"; exit 1; }
rm -rf "$DISPATCH_DLQ_DIR"

# Case D: 404 → fail-fast, exactly 1 attempt.
D="$TMP/D"; _make_shim "$D" 404 404 404
if _run "$D" hermes >/dev/null 2>&1; then echo "FAIL D: expected nonzero"; exit 1; fi
[ "$(wc -l < "$D/count")" -eq 1 ] || { echo "FAIL D: expected 1 attempt"; exit 1; }
rm -rf "$DISPATCH_DLQ_DIR"

# Case E: jitter window (loose bound — CI scheduler can stretch delays upward).
# Assert MIN observed delay >= 0.4 * base AND MAX observed delay <= 5 * cap.
# Tight per-call asserts (0.5..1.5x base) are too brittle under shared CI.
E="$TMP/E"; _make_shim "$E" 503 503 503
# Exhausted retries are expected to exit nonzero here; we only assert on the
# observed jitter delays, so ignore the exit status without `|| true`.
if DISPATCH_BASE_DELAY_MS=20 DISPATCH_MAX_DELAY_MS=80 DISPATCH_MAX_ATTEMPTS=3 \
     _run "$E" hermes >/dev/null 2>&1; then :; fi
mn=$(sort -n "$E/delays" | head -n1)
mx=$(sort -n "$E/delays" | tail -n1)
[ "${mn:-0}" -ge 8 ]   || { echo "FAIL E: min delay $mn ms below 8 (0.4*base)"; exit 1; }
[ "${mx:-0}" -le 400 ] || { echo "FAIL E: max delay $mx ms above 400 (5*cap)"; exit 1; }

# Case F: jq-encoded DLQ survives binary-ish body (no python3 needed).
F="$TMP/F"
mkdir -p "$F"
: > "$F/count"
printf '0' > "$F/last_ts_ms"
cat >"$F/curl" <<'SHIM'
#!/usr/bin/env bash
n=$(($(wc -l < "${SHIM_DIR}/count" 2>/dev/null || echo 0) + 1))
seq 1 "$n" > "${SHIM_DIR}/count"
printf 'weird"body\\with\nquotes\000nul\n503\n'
SHIM
chmod +x "$F/curl"
# Single attempt on a 503 exhausts immediately and exits nonzero; we only
# inspect the resulting DLQ file, so ignore the exit status without `|| true`.
if DISPATCH_MAX_ATTEMPTS=1 SHIM_DIR="$F" PATH="$F:$PATH" \
     "$REPO_ROOT/scripts/dispatch-apply.sh" hermes >/dev/null 2>&1; then :; fi
# Glob directly (find/glob handle odd filenames better than `ls`); take the first match.
dlq_files=("$DISPATCH_DLQ_DIR"/*-hermes.json)
f="${dlq_files[0]}"
jq -e '.last_body | type == "string"' "$f" >/dev/null \
  || { echo "FAIL F: DLQ JSON malformed under binary body"; exit 1; }

echo "OK: all 6 cases passed"
