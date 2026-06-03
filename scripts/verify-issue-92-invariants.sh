#!/usr/bin/env bash
# Asserts the three invariants from issue #92 are still present in
# dagger/src/index.ts. Runs as a static source-code check (no Dagger
# invocation, no timing).
set -euo pipefail

cd "$(dirname "$0")/.."
src="dagger/src/index.ts"

fail=0

# Invariant 1: lintTsc mounts an npm cache volume named proteus-npm-cache.
if ! grep -qE 'withMountedCache\("/root/\.npm", dag\.cacheVolume\("proteus-npm-cache"\)\)' "$src"; then
  echo "FAIL[#92 inv-1]: npm cache mount missing in $src" >&2
  fail=1
fi

# Invariant 2: lintTsc narrows source to dagger/ (not the whole repo).
# Pull the lintTsc body and assert it (a) calls source.directory("dagger")
# and (b) does NOT mount the full source under /src.
lint_tsc_body=$(awk '/async lintTsc\(/,/^  \}/' "$src")
if ! grep -q 'source.directory("dagger")' <<<"$lint_tsc_body"; then
  echo "FAIL[#92 inv-2a]: lintTsc no longer narrows to dagger/" >&2
  fail=1
fi
if grep -q 'withMountedDirectory("/src", source)' <<<"$lint_tsc_body"; then
  echo "FAIL[#92 inv-2b]: lintTsc re-introduced full-repo /src mount" >&2
  fail=1
fi

# Invariant 3: lint() returns a structured JSON object, not concatenated text.
if ! grep -qE 'JSON\.stringify\(\{ ?shellcheck, ?tsc ?\}' "$src"; then
  echo "FAIL[#92 inv-3]: lint() output is no longer structured JSON" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "OK: all issue #92 invariants present in $src"
