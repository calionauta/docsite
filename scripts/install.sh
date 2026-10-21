#!/bin/bash
# install.sh — vendor the docs-site engine into a project, pinned to this SHA.
#
# Usage: scripts/install.sh /path/to/project [sha]
#   sha defaults to HEAD of this checkout.
#
# Copies:
#   src/build.mjs             -> <project>/site/build.mjs
#   src/releases.mjs          -> <project>/site/releases.mjs
#   src/search.mjs            -> <project>/site/search.mjs
#   src/search.js             -> <project>/site/search/search.js
#   src/vendor/minisearch.js  -> <project>/site/search/minisearch.js
#   src/vendor/package.json   -> <project>/site/search/package.json
#   src/vendor/MINISEARCH-*   -> <project>/site/search/
#   src/site-layout.test.mjs  -> <project>/scripts/site-layout.test.mjs
#   scripts/check-drift.sh    -> <project>/scripts/check-docsite-drift.sh
#   scripts/bump.sh           -> <project>/scripts/bump-docsite.sh
# Writes <project>/site/UPSTREAM_SHA.
#
# It never overwrites site/docsite.config.mjs: that file belongs to the project.
set -euo pipefail

target="${1:?usage: scripts/install.sh /path/to/project [sha]}"
root=$(cd "$(dirname "$0")/.." && pwd)
sha="${2:-$(git -C "$root" rev-parse HEAD 2>/dev/null || echo unknown)}"

# Vendoring a dirty tree would pin a SHA that does not contain what was copied.
if [ -z "${2:-}" ] && ! git -C "$root" diff --quiet; then
	echo "refusing to vendor from a dirty checkout; commit or pass a SHA explicitly" >&2
	exit 1
fi

[ -d "$target" ] || { echo "no such directory: $target" >&2; exit 1; }
mkdir -p "$target/site" "$target/scripts"

cp "$root/src/build.mjs" "$target/site/build.mjs"
cp "$root/src/releases.mjs" "$target/site/releases.mjs"
cp "$root/src/search.mjs" "$target/site/search.mjs"
mkdir -p "$target/site/search"
cp "$root/src/search.js" "$target/site/search/search.js"
cp "$root/src/vendor/minisearch.js" "$target/site/search/minisearch.js"
cp "$root/src/vendor/package.json" "$target/site/search/package.json"
cp "$root/src/vendor/MINISEARCH-LICENSE.txt" "$target/site/search/MINISEARCH-LICENSE.txt"
cp "$root/src/site-layout.test.mjs" "$target/scripts/site-layout.test.mjs"
cp "$root/scripts/check-drift.sh" "$target/scripts/check-docsite-drift.sh"
cp "$root/scripts/bump.sh" "$target/scripts/bump-docsite.sh"
chmod +x "$target/scripts/check-docsite-drift.sh" "$target/scripts/bump-docsite.sh"
printf '%s\n' "$sha" > "$target/site/UPSTREAM_SHA"

if [ ! -f "$target/site/docsite.config.mjs" ]; then
	echo "→ wrote a config template; fill in name, base, repo and manifest:" >&2
	echo "  $target/site/docsite.config.mjs" >&2
	cat > "$target/site/docsite.config.mjs" <<'CONFIG'
export default {
  name: "my-project",
  base: "https://calionauta.github.io/my-project",
  repo: "calionauta/my-project",
  branch: "master",
  manifest: [
    // { group: "Start", slug: "overview", file: "overview.md", desc: "One line." },
  ],
  releases: [
    // { file: "CHANGELOG.md", origin: "", repo: "calionauta/my-project", tagPrefix: "v" },
  ],
};
CONFIG
fi

echo "✓ vendored docsite at $sha into $target"
