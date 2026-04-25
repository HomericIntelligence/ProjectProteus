import { dag, Container, Directory, object, func } from "@dagger.io/dagger"

@object()
export class Proteus {
  /**
   * Build an OCI image from a Dockerfile in the given context directory.
   * Returns the image digest.
   * @param publish - Whether to push the image to the registry (default: true)
   */
  @func()
  async build(
    context: Directory,
    name: string,
    tag: string = "latest",
    registry: string = "ghcr.io/homeric-intelligence",
    publish: boolean = true
  ): Promise<string> {
    const ref = `${registry}/${name}:${tag}`
    const image = dag
      .container()
      .build(context)

    if (publish) {
      const published = await image.publish(ref)
      return published
    } else {
      const digest = await image.id()
      return digest
    }
  }

  /**
   * Run a test command inside a container built from the source directory.
   * Returns the combined stdout/stderr output.
   * @param baseImage - Base image to use for the test container (default: ubuntu:22.04)
   */
  @func()
  async test(
    source: Directory,
    command: string = "just test",
    baseImage: string = "ubuntu:22.04"
  ): Promise<string> {
    const output = await dag
      .container()
      .from(baseImage)
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
