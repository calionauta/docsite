#!/bin/bash
# self-test.sh — build the fixture site and run the layout contract on it.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d "$root/.selftest.XXXXXX")  # inside the repo so node resolves node_modules
trap 'rm -rf "$work"' EXIT
cp -R "$root/fixtures/demo/." "$work/"
mkdir -p "$work/site/search" "$work/scripts"
cp "$root/src/build.mjs" "$root/src/releases.mjs" "$root/src/search.mjs" "$work/site/"
cp "$root/src/search.js" "$work/site/search/search.js"
cp "$root/src/vendor/minisearch.js" "$root/src/vendor/package.json" "$root/src/vendor/MINISEARCH-LICENSE.txt" "$work/site/search/"
cp "$root/src/site-layout.test.mjs" "$work/scripts/"
cd "$work"
node site/build.mjs
node -e '
const { readFileSync } = require("node:fs");
const MiniSearch = require("./site/search/minisearch.js");
const index = MiniSearch.loadJSON(readFileSync("./site/search/index.json", "utf8"), {
  fields: ["title", "headings", "text"],
  storeFields: ["title", "group", "path", "excerpt"],
  idField: "id",
});
const results = index.search("tabel", { prefix: true, fuzzy: 0.3 });
if (!results.length) { console.error("search self-test: no fuzzy result for tabel"); process.exit(1); }
console.log(`search ok: ${results.length} fuzzy result(s)`);
'
node scripts/site-layout.test.mjs
