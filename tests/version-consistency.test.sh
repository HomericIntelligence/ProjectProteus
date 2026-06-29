#!/usr/bin/env bash
# Tests version consistency across manifests and CHANGELOG.
# Regression guard for issue #101 — see docs/audit-2026-04-28/remediation-plan.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# 1. Extract canonical version from pixi.toml.
PIXI_VERSION=$(grep -E '^version[[:space:]]*=' pixi.toml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
if [ -z "$PIXI_VERSION" ]; then
  echo "FAIL: could not extract version from pixi.toml" >&2
  exit 1
fi

# 2. Verify dagger/package.json declares the same version.
DAGGER_VERSION=$(grep -E '"version"[[:space:]]*:' dagger/package.json | head -1 | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
if [ "$PIXI_VERSION" != "$DAGGER_VERSION" ]; then
  echo "FAIL: pixi.toml version ($PIXI_VERSION) != dagger/package.json version ($DAGGER_VERSION)" >&2
  exit 1
fi

# 3. Verify CHANGELOG.md exists and contains a dated section for the canonical version.
if [ ! -f CHANGELOG.md ]; then
  echo "FAIL: CHANGELOG.md missing at repo root" >&2
  exit 1
fi
if ! grep -qE "^## \[${PIXI_VERSION}\] - [0-9]{4}-[0-9]{2}-[0-9]{2}" CHANGELOG.md; then
  echo "FAIL: CHANGELOG.md has no dated section '## [${PIXI_VERSION}] - YYYY-MM-DD'" >&2
  exit 1
fi

echo "PASS: version consistency ($PIXI_VERSION across pixi.toml, dagger/package.json, CHANGELOG.md)"
