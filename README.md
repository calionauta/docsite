# docsite

One docs-site engine, vendored into each project, with the layout rules enforced
by a browser test. Zero npm dependencies at build time: node stdlib plus one
vendored JavaScript search library.

The point is not the CSS. The point is that a fix lands **here once** and every
project picks it up with a version bump, and that no project can ship a page
whose navigation disappears or whose tables clip, because the test measures the
rendered page at phone, tablet and desktop widths.

## What a project gets

- `site/build.mjs` — markdown → static HTML, one **markdown copy per page**
  (`docs/<slug>.md`, for agents), `llms.txt`, `llms-full.txt`, `sitemap.xml`, one
  article page per release section, and the search index.
- `site/releases.mjs` — the CHANGELOG → release-article renderer.
- `site/search.mjs` — build-time index builder and page hooks.
- `site/search/search.js` — the browser palette, keyboard handling and results.
- `site/search/minisearch.js` — vendored MiniSearch (MIT), no npm install and no
  other-language binary. `site/search/package.json` scopes it as CommonJS for
  projects whose package is `type: module`.
- `scripts/site-layout.test.mjs` — Chromium test over every page at nine widths,
  plus one search smoke.
- `scripts/markdown-mirror.test.mjs` — the copy contract: every published page
  has a `docs/<slug>.md`, one title, live links, its page URL, an `llms.txt`
  entry and a sitemap entry. No browser needed.
- `site/docsite.config.mjs` — the only project-specific file.

The search index is written to `site/search/index.json` at build time. That file
is generated: add `site/search/index.json` to the project's `.gitignore`; the
three search assets above are committed and drift-checked.

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
node site/build.mjs                 # build
node site/build.mjs --check         # links + anchors only, no writes
node scripts/markdown-mirror.test.mjs
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
| `unpublishedDirs` | no | `["domain/", "migrations/"]` — `docs/` subdirectories that are deliberately repo-facing. Every other `.md` under `docs/` must be in the manifest, or the build fails |
| `unpublishedFiles` | no | single pages kept repo-facing (`"SECURITY.md"`); same rule as `unpublishedDirs`, for a file that has no directory of its own |
| `description` | no | one-line site description; used for `<meta name="description">` on pages without a `desc`, for the `llms.txt` blurb, and for release pages |
| `socialPreview` | no | absolute or root-relative image URL, rendered as `og:image` and as a `summary_large_image` card |
| `landingMenuBelow` | no | width at which the landing menu must appear; 620 by default |
| `search` | no | `false` disables the search button, index and smoke; enabled by default |

## Agent surface

Three surfaces, each for a different question:

| Surface | Answers | Cost |
|---|---|---|
| `/llms.txt` | "what exists?" — one line per page, with its site URL and its markdown copy | 20 KB |
| `/<slug>.md` | "read this one page" — the page's own markdown, links rewritten to sibling copies | one page |
| `/llms-full.txt` | "give me everything" — every page concatenated, `Source:` naming the site URL | 1 MB+ |

The per-page copy is the important one, and it is why a markdown mirror exists at
all. `llms-full.txt` used to be the only machine surface, so an agent that wanted
one page paid for the whole site, and its `Source:` lines named repo-relative
paths (`docs/overview.md`) that **404 on the site** — a raw dump pretending to be
a URL. A copy is a real file, so it needs no rewrite rule, no `Accept:
text/markdown` negotiation, and no server: it works on GitHub Pages, on a local
`file://` path, and from any HTTP client.

Each page carries a `view markdown` link next to the content, and the copy is in
the sitemap. Both surfaces render from **one** renderer: the copy is produced by
re-rendering the page body with link rewriting aimed at the copies, then turned
back into markdown. A second parser would be a second thing to fix.

Two rules keep the surface honest, and both fail the build rather than warn:

- every `.md` under `docs/` is either published in the manifest or declared in
  `unpublishedDirs` / `unpublishedFiles`. A page nobody publishes and nobody
  declares reaches no reader at all, and that used to be silent;
- when the project keeps a curated `llms.txt` at the repository root (the file an
  agent is told to read first), every published page must be named in it. Two
  agent indexes with nothing comparing them is how a page stays published and
  unreachable for months.

## Page metadata

Every page gets `rel=canonical`, `og:title`, `og:type`, `og:url`, `og:site_name`,
`twitter:card`, and — when the manifest entry has a `desc`, or the config has a
`description` — `description` plus the matching `og:`/`twitter:` pair and an
`og:image` from `socialPreview`. Before this, a page's head was a `<title>` and
nothing else, so 80+ pages were unindexable with an unused description sitting
beside them in the manifest, and a shared link had no title, description or
image at all.

Release pages describe themselves with the release entry's own lede.

## Images

Images are resolved against the repository, not the site: the builder copies no
assets into `site/`, so a relative `![](shot.png)` is broken on **both** surfaces
(the page renders it under `/docs/<slug>/`, the copy at the site root, and
neither directory holds the file). `![...](shot.png)` becomes
`https://github.com/<repo>/raw/<branch>/<path>`, which renders on both and needs
no copying step to drift.

## Search

Search is lexical, not semantic: MiniSearch indexes each manifest page's title,
headings and text at build time. The browser loads the index on first use, then
searches with prefix matching, edit-distance fuzzy matching and title/heading
boosts. It needs no server, no WASM and no Rust binary.

Open it with the sidebar button, the mobile topbar button, `/` outside an input,
or `Ctrl/Cmd+K`. Results link to the rendered page.

Set `search: false` in the config when a project does not want the palette; the
build then skips the index and the layout test skips its search smoke.

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
- the docs index opens the search palette and a term from its first page returns
  a result

## The markdown-mirror contract

`markdown-mirror.test.mjs` fails when any of these is untrue, for every manifest
page:

- a copy was emitted, opens with the page's title, and has exactly **one** H1
- the copy keeps its page-URL breadcrumb, and every relative link in it names a
  file the build emitted
- no image in the copy has a site-relative URL
- no list collapsed onto one line (the items are adjacent in the HTML, so the
  parser has to split them) and no blank line splits a table
- the page has `rel=canonical` pointing at itself, the OG/Twitter pair, and the
  manifest `desc` in its description
- `llms.txt` names the copy, `llms-full.txt` names the **site** URL once per
  page, and the sitemap carries the copy

`self-test.sh` additionally proves both build rules by making them fail: an
unpublished, undeclared `docs/*.md` and a published page missing from a curated
`llms.txt` must each stop the build.

## Pin, drift and bump

`site/UPSTREAM_SHA` records the commit that was vendored. A consumer's scheduled
workflow runs:

```sh
scripts/check-drift.sh
```

which compares the vendored files against that commit on GitHub and fails when
they differ. To move to a newer upstream commit, run `scripts/bump.sh` (re-vendors
from upstream `main` and moves the pin), then commit the vendored files with the
SHA change. Treat them as read-only: a local edit is drift the check will flag.

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
