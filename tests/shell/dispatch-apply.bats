#!/usr/bin/env bats

setup() {
  TESTDIR="$(mktemp -d)"
  STUB_DIR="$BATS_TEST_DIRNAME/stubs"
  export PATH="$STUB_DIR:/usr/bin:/bin"
  export STUB_LOG="$TESTDIR/stub.log"
  : > "$STUB_LOG"
  export GITHUB_TOKEN="test-token"
  SCRIPT="$BATS_TEST_DIRNAME/../../scripts/dispatch-apply.sh"
}

teardown() { rm -rf "$TESTDIR"; }

@test "fails when GITHUB_TOKEN missing" {
  unset GITHUB_TOKEN
  run "$SCRIPT" hermes
  [ "$status" -eq 1 ]
  [[ "$output" == *"GITHUB_TOKEN is required"* ]]
}

@test "#15 regression seed: sends client_payload.host matching the arg" {
  run "$SCRIPT" hermes
  [ "$status" -eq 0 ]
  grep -q '"event_type":"agamemnon-apply"' "$STUB_LOG"
  grep -q '"client_payload":{"host":"hermes"}' "$STUB_LOG"
}

@test "host arg overrides HOST env var" {
  HOST=fromenv run "$SCRIPT" fromarg
  [ "$status" -eq 0 ]
  grep -q '"host":"fromarg"' "$STUB_LOG"
}

@test "uses MYRMIDONS_REPO from env in the URL" {
  MYRMIDONS_REPO="HomericIntelligence/Other" run "$SCRIPT" hermes
  [ "$status" -eq 0 ]
  grep -q "https://api.github.com/repos/HomericIntelligence/Other/dispatches" "$STUB_LOG"
}
