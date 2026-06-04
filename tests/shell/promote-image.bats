#!/usr/bin/env bats

setup() {
  TESTDIR="$(mktemp -d)"
  STUB_DIR="$BATS_TEST_DIRNAME/stubs"
  # Sealed PATH per bats-shell-testing skill: real skopeo cannot leak in.
  export PATH="$STUB_DIR:/usr/bin:/bin"
  export STUB_LOG="$TESTDIR/stub.log"
  : > "$STUB_LOG"
  SCRIPT="$BATS_TEST_DIRNAME/../../scripts/promote-image.sh"
}

teardown() { rm -rf "$TESTDIR"; }

@test "fails with usage on zero args" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "calls skopeo copy with docker:// prefix on both refs" {
  run "$SCRIPT" --quiet ghcr.io/x/foo:staging ghcr.io/x/foo:latest
  [ "$status" -eq 0 ]
  grep -q "skopeo copy docker://ghcr.io/x/foo:staging docker://ghcr.io/x/foo:latest" "$STUB_LOG"
}

@test "#2 regression seed: multi-arch digest ref is preserved verbatim" {
  run "$SCRIPT" --quiet ghcr.io/x/foo@sha256:abc ghcr.io/x/foo:latest
  [ "$status" -eq 0 ]
  grep -q "docker://ghcr.io/x/foo@sha256:abc" "$STUB_LOG"
}

@test "exits non-zero when SOURCE inspect fails (not destination)" {
  STUB_FAIL_INSPECT_SOURCE=1 run "$SCRIPT" --quiet ghcr.io/x/missing:staging ghcr.io/x/missing:latest
  [ "$status" -ne 0 ]
  [[ "$output" == *"Source image not found"* ]]
}
