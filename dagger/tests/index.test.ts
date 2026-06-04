import { describe, it, expect, vi, beforeEach } from "vitest"

const publishSpy = vi.fn(async (ref: string) => `${ref}@sha256:abc`)
const TERMINALS: Record<string, (...args: unknown[]) => unknown> = {
  stdout: () => Promise.resolve("MOCK_STDOUT"),
  id: () => Promise.resolve("sha256:xyz"),
  publish: (ref: unknown) => publishSpy(ref as string),
}

function chainable(): any {
  return new Proxy(function () {}, {
    get(_t, prop: string) {
      if (prop === "then") return undefined // not a thenable
      if (prop in TERMINALS) return TERMINALS[prop] // fn → Promise<value>
      return () => chainable() // sync intermediate
    },
    apply() {
      return chainable()
    },
  })
}

vi.mock("@dagger.io/dagger", () => ({
  dag: { container: () => chainable(), cacheVolume: () => chainable() },
  Directory: class {},
  Container: class {},
  object: () => (t: any) => t,
  func: () => (_t: any, _k: any, d: any) => d,
}))

import { Proteus } from "../src/index"

function dirMock(): any {
  return new Proxy(
    {},
    {
      get(_t, prop: string) {
        if (prop === "dockerBuild") return () => chainable()
        if (prop === "directory") return () => dirMock()
        if (prop === "file") return () => chainable()
        return () => dirMock()
      },
    }
  )
}

beforeEach(() => publishSpy.mockClear())

describe("Proteus.build", () => {
  it("returns digest and never publishes when publish=false", async () => {
    expect(await new Proteus().build(dirMock(), "app")).toBe("sha256:xyz")
    expect(publishSpy).not.toHaveBeenCalled()
  })
  it("publishes to :tag-staging when publish=true (regression for #2)", async () => {
    await new Proteus().build(dirMock(), "app", "v1", "ghcr.io/x", true)
    expect(publishSpy).toHaveBeenCalledWith("ghcr.io/x/app:v1-staging")
  })
  it("uses :latest-staging when tag defaults", async () => {
    await new Proteus().build(dirMock(), "app", undefined as any, undefined as any, true)
    expect(publishSpy).toHaveBeenCalledWith(
      "ghcr.io/homeric-intelligence/app:latest-staging"
    )
  })
})

describe("Proteus.test/lint chains", () => {
  it("test() awaits the terminal stdout()", async () =>
    expect(new Proteus().test(dirMock())).resolves.toBe("MOCK_STDOUT"))
  it("lintShellcheck and lintTsc each await stdout()", async () => {
    const p = new Proteus()
    await expect(p.lintShellcheck(dirMock())).resolves.toBe("MOCK_STDOUT")
    await expect(p.lintTsc(dirMock())).resolves.toBe("MOCK_STDOUT")
  })
  it("lint() returns JSON with shellcheck + tsc keys", async () => {
    const result = await new Proteus().lint(dirMock())
    expect(result).toContain("=== shellcheck ===")
    expect(result).toContain("=== tsc ===")
  })
})
