# docsite

One docs-site engine, vendored into each project, with the layout rules enforced
by a browser test. Zero dependencies at build time: node stdlib only.

The point is not the CSS. The point is that a fix lands **here once** and every
project picks it up with a version bump, and that no project can ship a page
whose navigation disappears or whose tables clip, because the test measures the
rendered page at phone, tablet and desktop widths.

## What a project gets

- `site/build.mjs` — markdown → static HTML, `llms.txt`, `llms-full.txt`,
  `sitemap.xml`, and one article page per release section.
- `site/releases.mjs` — the CHANGELOG → release-article renderer.
- `scripts/site-layout.test.mjs` — Chromium test over every page at nine widths.
- `site/docsite.config.mjs` — the only project-specific file.

The landing page is not generated. Marketing pages stay hand-written in
`site/index.html`; the test measures them when they exist.

## Install into a project

```sh
git clone https://github.com/calionauta/docsite
cd docsite
scripts/install.sh ../my-project          # copies the engine + test, pins the SHA
$EDITOR ../my-project/site/docsite.config.mjs
```

`install.sh` copies the engine, the layout test, the drift checker and the bump
script, and writes `site/UPSTREAM_SHA`. Commit them. From then on:

```sh
node site/build.mjs            # build
node site/build.mjs --check    # links + anchors only, no writes
node scripts/site-layout.test.mjs
```

Add both to CI. A project that publishes on GitHub Pages should run the layout
test before the upload step, so a clipped page cannot ship.

## Config

`site/docsite.config.mjs` is a default export:

| field | required | meaning |
|---|---|---|
| `name` | yes | site name in titles, the home link and `llms.txt` |
| `base` | yes | absolute site URL; the path becomes the sitemap prefix |
| `repo` | yes | `owner/name`, used for links to files outside `docs/` |
| `branch` | no | `master` by default; the branch for those blob URLs |
| `docsDir` | no | `docs` |
| `outDir` | no | `site` |
| `manifest` | yes | `{group, slug, file, desc}` per page; slugs are stable URLs |
| `releases` | no | `{file, origin, repo, tagPrefix}` per CHANGELOG source |
| `strictManifestLinks` | no | `false` allows `.md` files inside `docs/` that are not published |
| `landingMenuBelow` | no | width at which the landing menu must appear; 620 by default |

## The landing page

The landing stays hand-written. If `site/index.html` exists, the layout test
holds it to two rules:

- a `<details class="mobile-menu">` with the section links, visible at and below
  `landingMenuBelow` (620 by default). Below that width the header links no
  longer fit, and without the menu a phone has no navigation.
- no `<pre>` scrolls horizontally: wrap commands with
  `white-space: pre-wrap; overflow-wrap: anywhere` and reserve the copy button's
  gutter with `padding-right`, or the button lands on top of the command.

## Migrating a hand-written builder

1. Extract the page list from the old `site/build.mjs` into
   `site/docsite.config.mjs` first (`manifest` and `releases`); the engine no
   longer carries it.
2. Run `scripts/install.sh .` and commit the vendored files with the pin.
3. Build before and after if you can, and diff the output: the engine should
   render the same pages. If it differs, the old builder had a fork that has to
   go upstream, not into the config.

## The contract

`site-layout.test.mjs` fails when any of these is untrue:

- no page scrolls sideways at 380, 390, 400, 768, 1024, 1103, 1280, 1440, 1920
- below 820px a table stacks into labelled cards; above it, a table fits at
  desktop widths or scrolls at most a quarter of its box
- prose stays inside a 560-700px reading measure
- docs pages have a sidebar above 900px and a labelled menu below it
- a landing page has its menu below 620px and no command block that scrolls
- every table region has `role`, an `aria-label`, and `tabindex` only when it
  actually scrolls; every header cell has `scope="col"`; every cell carries the
  `data-label` the stacked layout prints

## Pin, drift and bump

`site/UPSTREAM_SHA` records the commit that was vendored. A consumer's scheduled
workflow runs:

```sh
scripts/check-drift.sh
```

which compares the three vendored files against that commit on GitHub and fails
when they differ. To move to a newer upstream commit, run `scripts/bump.sh` (re-vendors from
upstream `main` and moves the pin), then commit the four files with the SHA
change. Treat the vendored files as read-only: a local edit is drift the check
will flag.

A weekly PR can do the bump for you. Note that a PR opened with `GITHUB_TOKEN`
does not trigger other workflows; close and reopen it once, or dispatch the
layout workflow manually, so the test runs before the merge. Copy this into the
consumer repo as `.github/workflows/docsite-bump.yml`:

```yaml
name: docsite bump
on:
  schedule: [{ cron: "0 7 * * 1" }]
  workflow_dispatch:
permissions:
  contents: write
  pull-requests: write
jobs:
  bump:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bash scripts/bump-docsite.sh
      - env:
          GH_TOKEN: ${{ github.token }}
        run: |
          if git diff --quiet; then echo "already current"; exit 0; fi
          sha=$(cat site/UPSTREAM_SHA)
          git config user.name "docsite-bot"
          git config user.email "docsite-bot@users.noreply.github.com"
          git checkout -b docsite/bump
          git commit -am "chore(site): bump docsite to $sha"
          git push -u origin docsite/bump --force
          gh pr create --title "chore(site): bump docsite to $sha" \
            --body "Re-vendors the docs engine at $sha. Review the diff and the layout test; the engine is not edited here." \
            || true
```
