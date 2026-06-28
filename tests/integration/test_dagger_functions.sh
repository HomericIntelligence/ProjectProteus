#!/usr/bin/env bash
# Integration tests for the Proteus Dagger module.
# Invoked by .github/workflows/_required.yml integration-tests job.
set -euo pipefail

fail() { echo "::error::$*" >&2; exit 1; }

# Wrap each dagger invocation in `timeout` so a hung Docker pull or cold
# Dagger cache surfaces a clear failure within the job's 20-min budget,
# rather than burning the whole budget on one call.
run_dagger() {
  timeout 600 dagger "$@"
}

echo "=== integration: dagger call test (custom command echoes marker) ==="
# Default base image for test() is ubuntu:22.04 (dagger/src/index.ts:48);
# `echo` is available container-side. Behavioral assertion: the marker we
# fed in via --command must appear in the captured output.
out=$(run_dagger call test --source . --command "echo proteus-integration-ok")
[[ "$out" == *"proteus-integration-ok"* ]] \
  || fail "dagger call test did not include marker in stdout; got: $out"

echo "=== integration: dagger call lint-shellcheck on repo ==="
# Success criterion: exit 0 from the dagger pipeline (caught by `set -euo
# pipefail` above). We capture output to a diagnostic file for failed-CI
# triage but do NOT assert on its size — a clean repo's shellcheck pass
# may produce empty output. (R4 fix.)
run_dagger call lint-shellcheck --source . > /tmp/shellcheck.out 2>&1

echo "All integration checks passed."
