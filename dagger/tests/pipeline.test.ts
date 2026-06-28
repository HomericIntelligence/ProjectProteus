import { test } from "node:test"
import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { stagingRef } from "../src/tag.ts"

test("just pipeline emits matching staging→production ref pair", () => {
  const repoRoot = new URL("../..", import.meta.url).pathname
  const result = spawnSync("just", ["--dry-run", "pipeline", "myapp"], {
    cwd: repoRoot,
    encoding: "utf8",
  })
  const out = result.stderr // just --dry-run outputs to stderr
  const expectedStaging = stagingRef("ghcr.io/homeric-intelligence", "myapp", "latest")
  const expectedProd = "ghcr.io/homeric-intelligence/myapp:latest"

  assert.match(
    out,
    /--publish/,
    "pipeline must invoke a publish step (with --publish flag) so the staging tag is pushed",
  )
  assert.ok(
    out.includes(`just promote ${expectedStaging} ${expectedProd}`),
    `expected promote line copying ${expectedStaging} → ${expectedProd}, got:\n${out}`,
  )
})
