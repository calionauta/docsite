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

`install.sh` writes `site/UPSTREAM_SHA`. Commit it. From then on:

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
when they differ. To move to a newer upstream commit, re-run `scripts/install.sh`
and commit the result with the SHA change. Treat the vendored files as read-only:
a local edit is drift the check will flag.
