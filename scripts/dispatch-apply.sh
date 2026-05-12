#!/usr/bin/env bash
# dispatch-apply.sh — Send a repository_dispatch event to trigger Myrmidons apply.
# Usage: HOST=hermes GITHUB_TOKEN=<token> MYRMIDONS_REPO=HomericIntelligence/Myrmidons \
#            ./scripts/dispatch-apply.sh [host]
# The HOST argument overrides the HOST env var if both are provided.

set -euo pipefail

HOST="${1:-${HOST:-hermes}}"
MYRMIDONS_REPO="${MYRMIDONS_REPO:-HomericIntelligence/Myrmidons}"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "Error: GITHUB_TOKEN is required." >&2
    exit 1
fi

echo "Dispatching agamemnon-apply to ${MYRMIDONS_REPO} for host: ${HOST}"

RESPONSE=$(curl --silent --connect-timeout 10 --max-time 30 --retry 3 --retry-delay 2 --write-out "\n%{http_code}" \
    --request POST \
    --url "https://api.github.com/repos/${MYRMIDONS_REPO}/dispatches" \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer ${GITHUB_TOKEN}" \
    --header "X-GitHub-Api-Version: 2022-11-28" \
    --data "{\"event_type\":\"agamemnon-apply\",\"client_payload\":{\"host\":\"${HOST}\"}}")

HTTP_CODE=$(printf '%s' "$RESPONSE" | tail -n1)
# Use sed to drop the last line (HTTP code) — portable across GNU and BSD
# (BSD `head` does not support the GNU-only `-n-1` extension).
BODY=$(printf '%s' "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" -eq 204 ]]; then
    echo "Dispatch successful (204 No Content). Myrmidons apply triggered for host: ${HOST}"
else
    echo "Dispatch failed with HTTP ${HTTP_CODE}:" >&2
    echo "$BODY" >&2
    exit 1
fi
