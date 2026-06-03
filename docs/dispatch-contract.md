# Cross-Repo Dispatch Contract

This document specifies the contract for `repository_dispatch` events flowing between homericintelligence repos and ProjectProteus.

## Inbound: AchaeanFleet → ProjectProteus (`image-pushed`)

AchaeanFleet sends `image-pushed` events to ProjectProteus when a new OCI image is built and pushed to a registry.

| Field | Type | Required | Consumed At | Notes |
|-------|------|----------|-------------|-------|
| `host` | string | **REQUIRED** | `.github/workflows/cross-repo-dispatch.yml:36` | Target host for `agamemnon-apply` dispatch. If absent, missing, or empty, the `Require client_payload.host` step fails the workflow with `::error::` — see issue #84. |
| `image` | string | No | Not consumed | Advisory field; documented in `AGENTS.md:38-40`. Future consumers should normalize via `docs/dispatch-contract.md`. |
| `tag` | string | No | Not consumed | Advisory field; documented in `AGENTS.md:38-40`. Future consumers should normalize via `docs/dispatch-contract.md`. |
| `image_tag` | string | No | Not consumed | Advisory field; documented in `AGENTS.md:38-40`. Future consumers should normalize via `docs/dispatch-contract.md`. |
| `source` | string | No | Not consumed | Advisory field; documented in `AGENTS.md:38-40`. Future consumers should normalize via `docs/dispatch-contract.md`. |

**Source of truth**: AchaeanFleet's `notify-proteus.sh` script.

## Outbound: ProjectProteus → Myrmidons (`agamemnon-apply`)

ProjectProteus forwards the dispatch to Myrmidons with the following event:

```json
{
  "event_type": "agamemnon-apply",
  "client_payload": {
    "host": "<host-from-inbound>"
  }
}
```

**Sent by**: `scripts/dispatch-apply.sh:25`.

## Fail-Closed Behavior

If `host` is absent, missing, or empty in the inbound payload, ProjectProteus **fails closed**:

1. `.github/workflows/cross-repo-dispatch.yml:36` — the `Require client_payload.host` step detects the condition and logs `::error title=dispatch-contract::`.
2. The step exits with code 1, halting the workflow.
3. No `agamemnon-apply` dispatch is sent to Myrmidons.

**Rationale**: In multi-host deployments, a silent default to any host (e.g., `hermes`) would misroute applies and corrupt cluster state. Failing closed ensures operators must explicitly provide `host`; see issue #84.

## Local Verification

To verify the inbound contract with a test dispatch:

```bash
# Send a known-good payload (with host):
gh api repos/HomericIntelligence/ProjectProteus/dispatches \
  -f event_type=image-pushed \
  -f client_payload='{"host":"hermes","image":"myapp","tag":"1.0.0"}'

# Send a failing payload (missing host):
gh api repos/HomericIntelligence/ProjectProteus/dispatches \
  -f event_type=image-pushed \
  -f client_payload='{"image":"myapp","tag":"1.0.0"}'
# Expected: workflow run fails with ::error title=dispatch-contract:: annotation.
```

## Related Issues & Documents

- **Issue #84**: Fix the `host` field mismatch (this PR).
- **Issue #15**: Coordinate AchaeanFleet emitter to ensure `host` is always sent.
- **`AGENTS.md:38-40`**: Advisory fields and future normalization.
- **`.github/workflows/cross-repo-dispatch.yml`**: Inbound validation and dispatch.
- **`scripts/dispatch-apply.sh`**: Outbound dispatch to Myrmidons.
- **`docs/runbooks/cross-repo-dispatch-failure.md`**: Troubleshooting guide.
