#!/usr/bin/env bats

setup() {
  TMP="$(mktemp -d)"
  export PATH="$TMP:$PATH"
  cat > "$TMP/skopeo" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  inspect)
    case "$2" in
      docker://missing/*) exit 1 ;;
      docker://*)
        if [[ "${FAIL_DEST_INSPECT:-0}" == "1" && "$2" == "docker://${DEST_REF:-NONE}" ]]; then
          exit 1
        fi
        printf 'sha256:deadbeef'
        ;;
    esac ;;
  copy)  exit 0 ;;
  login) exit 0 ;;
esac
STUB
  chmod +x "$TMP/skopeo"
}
teardown() { rm -rf "$TMP"; }

@test "happy path: promotes and verifies destination" {
  run ./scripts/promote-image.sh ghcr.io/x/app:staging ghcr.io/x/app:latest
  [ "$status" -eq 0 ]
}

@test "fails when source image missing" {
  run ./scripts/promote-image.sh missing/x:t ghcr.io/x/app:latest
  [ "$status" -ne 0 ]
  [[ "$output" == *"Source image not found"* ]]
}

@test "fails when post-promote inspect of destination fails" {
  DEST_REF=ghcr.io/x/app:latest FAIL_DEST_INSPECT=1 \
    run ./scripts/promote-image.sh ghcr.io/x/app:staging ghcr.io/x/app:latest
  [ "$status" -ne 0 ]
}
