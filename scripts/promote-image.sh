#!/usr/bin/env bash
# promote-image.sh — Copy an OCI image between registries using skopeo.
# Usage: ./scripts/promote-image.sh <source-ref> <dest-ref>
# Example: ./scripts/promote-image.sh ghcr.io/homeric-intelligence/myapp:staging \
#                                      ghcr.io/homeric-intelligence/myapp:latest

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <source-image-ref> <dest-image-ref>" >&2
    exit 1
fi

SRC="$1"
DEST="$2"

echo "Promoting image:"
echo "  SRC:  $SRC"
echo "  DEST: $DEST"

echo "Verifying source image: ${SRC}"
if ! skopeo inspect "docker://${SRC}" > /dev/null 2>&1; then
  echo "ERROR: Source image not found or not accessible: ${SRC}" >&2
  exit 1
fi

skopeo copy "docker://${SRC}" "docker://${DEST}"

echo "Promotion complete: ${DEST}"
