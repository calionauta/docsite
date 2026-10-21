// Fixture config: the demo project used by scripts/self-test.sh.
export default {
  name: "demo",
  base: "https://example.com/demo",
  repo: "example/demo",
  branch: "main",
  manifest: [
    { group: "Start", slug: "intro", file: "intro.md", desc: "What the fixture covers." },
    { group: "Start", slug: "tables", file: "tables.md", desc: "Table shapes: wide cells and long tokens." },
  ],
  releases: [
    { file: "CHANGELOG.md", origin: "", repo: "example/demo", tagPrefix: "v" },
  ],
};
