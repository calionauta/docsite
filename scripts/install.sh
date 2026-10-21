#!/bin/bash
# install.sh — vendor the docs-site engine into a project, pinned to this SHA.
#
# Usage: scripts/install.sh /path/to/project [sha]
#   sha defaults to HEAD of this checkout.
#
# Copies:
#   src/build.mjs            -> <project>/site/build.mjs
#   src/releases.mjs         -> <project>/site/releases.mjs
#   src/site-layout.test.mjs -> <project>/scripts/site-layout.test.mjs
# Writes <project>/site/UPSTREAM_SHA.
#
# It never overwrites site/docsite.config.mjs: that file belongs to the project.
set -euo pipefail

target="${1:?usage: scripts/install.sh /path/to/project [sha]}"
root=$(cd "$(dirname "$0")/.." && pwd)
sha="${2:-$(git -C "$root" rev-parse HEAD 2>/dev/null || echo unknown)}"

[ -d "$target" ] || { echo "no such directory: $target" >&2; exit 1; }
mkdir -p "$target/site" "$target/scripts"

cp "$root/src/build.mjs" "$target/site/build.mjs"
cp "$root/src/releases.mjs" "$target/site/releases.mjs"
cp "$root/src/site-layout.test.mjs" "$target/scripts/site-layout.test.mjs"
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
