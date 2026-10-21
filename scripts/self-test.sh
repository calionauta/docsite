#!/bin/bash
# self-test.sh — build the fixture site and run the layout contract on it.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d "$root/.selftest.XXXXXX")  # inside the repo so node resolves node_modules
trap 'rm -rf "$work"' EXIT
cp -R "$root/fixtures/demo/." "$work/"
mkdir -p "$work/site" "$work/scripts"
cp "$root/src/build.mjs" "$root/src/releases.mjs" "$work/site/"
cp "$root/src/site-layout.test.mjs" "$work/scripts/"
cd "$work"
node site/build.mjs
node scripts/site-layout.test.mjs
