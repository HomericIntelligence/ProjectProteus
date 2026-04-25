import { dag, Container, Directory, object, func } from "@dagger.io/dagger"

@object()
export class Proteus {
  /**
   * Build an OCI image from a Dockerfile in the given context directory.
   * Returns the image digest.
   */
  @func()
  async build(
    context: Directory,
    name: string,
    tag: string = "latest",
    registry: string = "ghcr.io/homeric-intelligence"
  ): Promise<string> {
    const ref = `${registry}/${name}:${tag}`
    const image = dag
      .container()
      .build(context)

    const published = await image.publish(ref)
    return published
  }

  /**
   * Run a test command inside a container built from the source directory.
   * Returns the combined stdout/stderr output.
   */
  @func()
  async test(
    source: Directory,
    command: string = "just test"
  ): Promise<string> {
    const output = await dag
      .container()
      .from("ubuntu:22.04")
      .withMountedDirectory("/src", source)
      .withWorkdir("/src")
      .withExec(["bash", "-c", command])
      .stdout()

    return output
  }

  /**
   * Run lint checks against the source directory.
   * Uses shellcheck for shell scripts and tsc for TypeScript.
   * Returns combined lint output.
   */
  @func()
  async lint(source: Directory): Promise<string> {
    const shellcheck = await dag
      .container()
      .from("koalaman/shellcheck-alpine:stable")
      .withMountedDirectory("/src", source)
      .withWorkdir("/src")
      .withExec(["sh", "-c", "find scripts/ -name '*.sh' | xargs shellcheck"])
      .stdout()

    const tsc = await dag
      .container()
      .from("node:20-alpine")
      .withMountedDirectory("/src", source)
      .withWorkdir("/src/dagger")
      .withExec(["sh", "-c", "npm ci && npx tsc --noEmit"])
      .stdout()

    return `=== shellcheck ===\n${shellcheck}\n=== tsc ===\n${tsc}`
  }
}
