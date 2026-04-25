#!/usr/bin/env bash
# promote-image.sh — Copy an OCI image between registries using skopeo.
# Usage: ./scripts/promote-image.sh <source-ref> <dest-ref>
# Example: ./scripts/promote-image.sh ghcr.io/homeric-intelligence/myapp:staging \
#                                      ghcr.io/homeric-intelligence/myapp:latest
#
# Authentication: set REGISTRY_USERNAME and REGISTRY_PASSWORD env vars for
# registry auth, or pre-authenticate via 'skopeo login' / 'docker login' before calling.

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <source-image-ref> <dest-image-ref>" >&2
    exit 1
fi

SRC="$1"
DEST="$2"

# Optional registry authentication via env vars
if [[ -n "${REGISTRY_USERNAME:-}" && -n "${REGISTRY_PASSWORD:-}" ]]; then
    REGISTRY=$(echo "${SRC}" | cut -d'/' -f1)
    echo "Authenticating with registry: ${REGISTRY}"
    echo "${REGISTRY_PASSWORD}" | skopeo login "${REGISTRY}" \
        --username "${REGISTRY_USERNAME}" \
        --password-stdin
fi

echo "Promoting image:"
echo "  SRC:  $SRC"
echo "  DEST: $DEST"

echo "Verifying source image: ${SRC}"
if ! skopeo inspect "docker://${SRC}" > /dev/null 2>&1; then
  echo "ERROR: Source image not found or not accessible: ${SRC}" >&2
  exit 1
fi

skopeo copy "docker://${SRC}" "docker://${DEST}"

echo "Verifying promotion to ${DEST}..."
DEST_DIGEST=$(skopeo inspect "docker://${DEST}" --format '{{.Digest}}' 2>/dev/null) || {
    echo "ERROR: Post-promotion verification failed — destination image not found or not accessible: ${DEST}" >&2
    exit 1
}
echo "Promotion verified successfully."
echo "  Source:      ${SRC}"
echo "  Destination: ${DEST}"
echo "  Digest:      ${DEST_DIGEST}"
