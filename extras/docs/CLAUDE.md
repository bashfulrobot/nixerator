# extras/docs/: the visual repo tour

`index.html` is a single-page, visual tour of this repo: the file map, module
anatomy, the archetype→suite→module cascade, the rebuild pipeline, the three
hosts, and the secrets flow. The goal is that someone understands the repo in
one scroll. This file is how to build and maintain that page.

Open it with `just docs` (which runs `xdg-open extras/docs/index.html`). No
server, no build step. Modeled on the same convention in
`~/git/homelab/docs/index.html` / `docs/CLAUDE.md`.

## What makes it work

- **Self-contained.** One HTML file, all CSS inline in a single `<style>`
  block. No external CSS, JS, fonts, or CDN. It opens offline, by
  double-click, and it renders to a clean PNG for sharing. If you reach for a
  `<link>` or `<script src>`, stop.
- **Honest to the repo.** Every box, path, option name, and number on the page
  comes from a real file: `modules/`, `hosts/*/modules.nix`, `justfile`,
  `settings/globals.nix`. A diagram that drifts from the code is worse than no
  diagram. When the repo changes, the page changes.
- **Few words.** Visual carries the meaning. Text is labels and one-line
  captions, not paragraphs. If a sentence repeats what a label already shows,
  cut it.
- **Plain voice.** Lowercase section headers, straight quotes, no em dashes
  (use a comma, colon, or a new sentence). Match the tone already in the file.
- **Not committed as a screenshot.** No PNG lives in the repo -- a committed
  snapshot would drift out of sync with the live HTML exactly like the old
  `nixerator-architecture.png` (exported from a now-retired `.drawio`) did.
  Render one on demand (below) if you need to share or check it on a phone.

## Colour means something

The palette is fixed and the legend at the bottom of the page documents it.
Keep it consistent, because the colour is doing work:

- blue (`--blue`): a directory or path
- purple (`--purple`): a Nix option path (`apps.cli.foo.enable`)
- teal (`--teal`): the key idea, the thing you want the eye to land on
- amber (`--amber`): archived or disabled
- green (`--green`): enabled, active

If you introduce a new meaning, give it a colour and add it to the legend.

## Building blocks

Reuse these components instead of inventing new CSS. They are all defined in
the `<style>` block at the top of `index.html`.

| Component | Class | Use for |
|-----------|-------|---------|
| Section header | `<h2>` (renders uppercase) | one per topic |
| Lead line | `<p class="lead">` | one sentence under a header |
| Tech badges | `.chips` / `.chip` | the stack row at the top |
| Annotated file tree | `<pre class="tree">` + spans `.d .f .an .ac .gi` | "the map" and code snippets |
| Card container | `.panel`, split with `.grid` + `.g2`/`.g3` | wrap any block |
| Numbered pipeline | `.pipe` + `.step` (`.num`, `.t`, `.res`) | an ordered process (e.g. the rebuild pipeline) |
| Left-to-right flow | `.flow` + `.node` + `.arrow` (`.arrow small` = arrow label) | a cascade or path |
| Concept cards | `.card` (`.k`, `.ic`) + `.tag` (`.live`/`.soon`) | grouped points, status |
| File-status rows | `.srow` + `.mk.ok` (✓) / `.mk.no` (✗/–) + `.note` | enabled vs archived, key facts |
| Inline code | `.kbd` (a command/flag in prose), `.mono` (a snippet) | naming files, commands, option paths |

To add a section: copy an existing `<h2>` + `.panel` block and swap in the
right component. Prefer an existing component over a new class. New classes go
with the others in `<style>`.

## Render a preview (PNG)

The page is meant for a browser, but to share a snapshot or check it on a
phone, rasterise the whole page:

```sh
OUT=/tmp/nixerator-repo-tour.png
google-chrome-stable --headless=old --disable-gpu --no-sandbox --hide-scrollbars \
  --force-device-scale-factor=2 --window-size=1200,8000 \
  --screenshot="$OUT" "file://$PWD/extras/docs/index.html"
magick "$OUT" -bordercolor '#0d1117' -border 1 -fuzz 2% -trim +repage "$OUT"
```

- `--headless=old` screenshots the whole window. Set `--window-size` height
  taller than the page, then trim the blank tail with `magick`.
- If the page outgrows the height, the trimmed image looks cut (content runs
  to the very bottom edge). Bump the height and re-render.
- The trim border colour must equal `--bg` (`#0d1117`) so only the uniform
  blank is removed, not real content.
- `--force-device-scale-factor=2` gives a crisp 2x image.
- To inspect one section, crop it: `magick "$OUT" -crop 1992x1300+0+<y> +repage section.png`.
- Do not commit the render (see "Not committed as a screenshot" above).

## When to update

- **New host.** Add it to "Three hosts, one repo" with its archetype and
  Tailscale IP (already published, not a secret -- see the comment in
  `settings/globals.nix`).
- **New/changed suite or archetype.** If the archetype→suite cascade changes,
  update "One archetype, many suites, many modules" and the module counts in
  "The map".
- **Module archived or restored.** Update the archive-count note in
  "Auto-import, and the archive convention".
- **`justfile` recipe changes** worth surfacing: add them to "Day-2".
- **Secrets flow changes** (new vault, new render path): update "Secrets:
  1Password, not git-crypt".
- **Always re-render** the preview after an edit. A broken layout is obvious
  in the PNG in a way it is not in the markup.
