import { test } from "node:test"
import assert from "node:assert/strict"
import { stagingRef, STAGING_SUFFIX } from "../src/tag.ts"

test("stagingRef appends -staging to bare tag", () => {
  assert.equal(
    stagingRef("ghcr.io/homeric-intelligence", "myapp", "latest"),
    "ghcr.io/homeric-intelligence/myapp:latest-staging",
  )
})

test("stagingRef preserves semver tags", () => {
  assert.equal(
    stagingRef("ghcr.io/homeric-intelligence", "myapp", "v1.2.3"),
    "ghcr.io/homeric-intelligence/myapp:v1.2.3-staging",
  )
})

test("STAGING_SUFFIX matches the contract justfile/promote-image.sh expect", () => {
  assert.equal(STAGING_SUFFIX, "-staging")
})
