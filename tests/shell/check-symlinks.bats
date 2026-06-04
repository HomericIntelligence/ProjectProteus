#!/usr/bin/env bats

setup() { TESTDIR="$(mktemp -d)"; cd "$TESTDIR"; mkdir .git; }
teardown() { cd /; rm -rf "$TESTDIR"; }

@test "exits 0 when no symlinks exist" {
  run bash "$BATS_TEST_DIRNAME/../../scripts/check-symlinks.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All symlinks are valid"* ]]
}

@test "exits 1 and reports broken symlinks" {
  ln -s /no/such/path broken
  run bash "$BATS_TEST_DIRNAME/../../scripts/check-symlinks.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Broken symlinks found"* ]]
}
