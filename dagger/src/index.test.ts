import { describe, it, expect, vi, beforeEach, type Mock } from "vitest"
import type { Directory } from "@dagger.io/dagger"

interface MockChain {
  from: Mock
  withMountedDirectory: Mock
  withMountedCache: Mock
  withWorkdir: Mock
  withFile: Mock
  withExec: Mock
  stdout: Mock
}

interface MockDirectory {
  directory: Mock
  file: Mock
  dockerBuild: Mock
}

const publish: Mock = vi.fn(async (ref: string) => `${ref}@sha256:deadbeef`)
const id: Mock = vi.fn(async () => "sha256:abc123")
const dockerBuild: Mock = vi.fn(() => ({ publish, id }))

const containerChain = {} as MockChain
for (const m of ["from", "withMountedDirectory", "withMountedCache",
                 "withWorkdir", "withFile", "withExec"] as const) {
  containerChain[m] = vi.fn(() => containerChain)
}
containerChain.stdout = vi.fn(async () => "ok")

const directoryStub = {} as MockDirectory
directoryStub.directory = vi.fn(() => directoryStub)
directoryStub.file = vi.fn(() => directoryStub)
directoryStub.dockerBuild = dockerBuild

vi.mock("@dagger.io/dagger", () => ({
  dag: { container: () => containerChain, cacheVolume: vi.fn(() => ({})) },
  Container: class {},
  Directory: class {},
  object: () => <T>(c: T): T => c,
  func: () => (): void => {},
}))

import { Proteus } from "./index"

const ctx = directoryStub as unknown as Directory

describe("Proteus.build (regression seed: #2 tag arithmetic, #91 publish opt-in)", () => {
  beforeEach(() => { vi.clearAllMocks() })

  it("does NOT publish by default (#91)", async () => {
    await new Proteus().build(ctx, "myapp")
    expect(publish).not.toHaveBeenCalled()
    expect(id).toHaveBeenCalledTimes(1)
  })

  it("publishes to <registry>/<name>:<tag> when publish=true (#2)", async () => {
    await new Proteus().build(ctx, "myapp", "v1.2.3",
                              "ghcr.io/homeric-intelligence", true)
    expect(publish).toHaveBeenCalledWith("ghcr.io/homeric-intelligence/myapp:v1.2.3")
  })

  it("defaults tag to 'latest' (#2)", async () => {
    // Use the literal default from index.ts:14 instead of `undefined as any`.
    await new Proteus().build(ctx, "myapp", "latest",
                              "ghcr.io/homeric-intelligence", true)
    expect(publish).toHaveBeenCalledWith("ghcr.io/homeric-intelligence/myapp:latest")
  })
})

describe("Proteus.test", () => {
  beforeEach(() => { vi.clearAllMocks() })

  it("runs the supplied command via bash -c", async () => {
    await new Proteus().test(ctx, "echo hello", "ubuntu:22.04")
    expect(containerChain.withExec).toHaveBeenCalledWith(["bash", "-c", "echo hello"])
  })
})

describe("Proteus.lint", () => {
  beforeEach(() => { vi.clearAllMocks() })

  it("returns JSON containing shellcheck and tsc keys", async () => {
    const out = await new Proteus().lint(ctx)
    expect(out).toContain("shellcheck")
    expect(out).toContain("tsc")
  })
})
