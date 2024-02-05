import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    root: "./tests",
    include: "**/*-{test,spec}.?(c|m)[jt]s?(x)"
  },
})