#!/bin/bash
# self-test.sh — build the fixture site and run the layout contract on it.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d "$root/.selftest.XXXXXX")  # inside the repo so node resolves node_modules
trap 'rm -rf "$work"' EXIT
cp -R "$root/fixtures/demo/." "$work/"
mkdir -p "$work/site/search" "$work/scripts"
cp "$root/src/build.mjs" "$root/src/releases.mjs" "$root/src/search.mjs" "$work/site/"
cp "$root/src/docsite.config.mjs" "$work/site/" 2>/dev/null || true
cp "$root/src/search.js" "$work/site/search/search.js"
cp "$root/src/vendor/minisearch.js" "$root/src/vendor/package.json" "$root/src/vendor/MINISEARCH-LICENSE.txt" "$work/site/search/"
cp "$root/src/site-layout.test.mjs" "$root/src/markdown-mirror.test.mjs" "$work/scripts/"
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
# The markdown mirror is a build-artifact contract; it runs before the browser
# pass so a broken copy fails fast and without needing Chromium.
node scripts/markdown-mirror.test.mjs "$work"

# ...and the two rules that protect it, each proved by making the build fail.
# A page nobody publishes and nobody declares reaches no reader: the build must
# refuse it rather than publish 80 pages and stay quiet about the 81st.
printf '# orphan\n\nNobody links this.\n' > docs/orphan.md
if node site/build.mjs --check >/dev/null 2>&1; then
  echo "check() accepted an unpublished, undeclared page" >&2; exit 1
fi
rm docs/orphan.md

# A single repo-facing page has no directory of its own, so the declaration has
# to accept a file name too — otherwise the only way to keep one page out of the
# site is to move it into a directory or publish it.
printf '# secret

Internal only.
' > docs/internal.md
sed -i.bak 's|^  strictManifestLinks.*|&|; s|^  manifest: \[|  unpublishedFiles: ["internal.md"],\n  manifest: [|' site/docsite.config.mjs
node site/build.mjs --check >/dev/null || {
  echo "check() rejected a page declared through unpublishedFiles" >&2; exit 1; }
sed -i.bak2 's|^  unpublishedFiles: \["internal.md"\],$||' site/docsite.config.mjs
if node site/build.mjs --check >/dev/null 2>&1; then
  echo "check() accepted an undeclared page after the declaration was removed" >&2; exit 1
fi
rm -f docs/internal.md site/docsite.config.mjs.bak site/docsite.config.mjs.bak2

# Once the project keeps a curated llms.txt at the repo root, a published page
# it never names is invisible to the agent that reads that file first.
printf '# demo\n\n- [Demo docs](docs/intro.md)\n' > llms.txt
if node site/build.mjs --check >/dev/null 2>&1; then
  echo "check() accepted a page missing from the curated llms.txt" >&2; exit 1
fi
printf '# demo\n\n- [Demo docs](docs/intro.md)\n- [Tables](docs/tables.md)\n' > llms.txt
node site/build.mjs --check >/dev/null || { echo "check() rejected a complete llms.txt" >&2; exit 1; }
rm llms.txt
echo "check rules ok: unpublished page, undeclared single page and incomplete llms.txt all fail; declared ones pass"
node scripts/site-layout.test.mjs
