export const STAGING_SUFFIX = "-staging"

export function stagingRef(registry: string, name: string, tag: string): string {
  return `${registry}/${name}:${tag}${STAGING_SUFFIX}`
}
