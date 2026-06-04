import { defineConfig } from "vitest/config"

export default defineConfig({
  test: {
    environment: "node",
    include: ["tests/**/*.test.ts"],
    coverage: {
      provider: "v8",
      reporter: ["text", "lcov"],
      thresholds: { lines: 70, statements: 70, functions: 70, branches: 60 },
      include: ["src/**/*.ts"],
    },
  },
})
