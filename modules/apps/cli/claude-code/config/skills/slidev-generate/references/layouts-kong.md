# Layout reference

Each layout is a `.vue` file under `layouts/`. To use one in `slides.md`, set `layout: <name>` in the slide's frontmatter.

| Layout                | Purpose                                       | Frontmatter props                                        |
|-----------------------|-----------------------------------------------|----------------------------------------------------------|
| `cover`               | Deck cover (title + eyebrow + speaker + date) | top-level: `eyebrow`, `speaker`, `date`, `tagline`      |
| `section`             | Section divider; one bold sentence            | `eyebrow`                                                |
| `content`             | Default title + body                          | `title`, `eyebrow`, `margin`                             |
| `two-cols`            | Two-column markdown                           | `title`, `eyebrow`, `margin`; uses `::left::` / `::right::` slots |
| `top-title-two-cols`  | Title across top + two columns below          | `title`, `eyebrow`, `margin`; uses `::left::` / `::right::` slots |
| `stats`               | Big-number grid (1-6 cells)                   | `title`, `eyebrow`, `footer`, `items: [{value,label,note}]` |
| `quote`               | Pull-quote with attribution                   | `attribution`                                            |
| `image`               | Side-by-side text + image                     | `title`, `eyebrow`, `src`, `alt`, `position: left/right` |
| `team`                | Headshot grid                                 | `title`, `eyebrow`, `people: [{name,title,image}]`       |
| `full`                | Full-bleed (no chrome) — hero image, diagrams, overlay annotations | _(none)_                              |
| `closing`             | Final "Thank you" slide                       | `contact`, `url`                                         |

---

## `cover`

```markdown
---
layout: cover
eyebrow: KONG QBR
speaker: Dustin Krysak, Staff Technical CSM
date: APRIL 2026
tagline: Quarterly review for Acme Corp.
---

# Acme x Kong<br/>April 2026
```

The Kong wordmark appears top-left automatically. `eyebrow` shows above the title, `speaker` and `date` along a lime hairline footer, and `tagline` directly under the title.

## `section`

Section divider used between major parts of the deck. Italic markdown (`_word_`) renders the wrapped text in lime.

```markdown
---
layout: section
eyebrow: WHY THIS MATTERS
---

# Connect every API. Every AI agent. _Every developer._
```

Keep to **one sentence** - this layout is meant to land hard.

## `content`

The 80% layout. Title at top, body below, lime hairline footer with the Kong mark.

```markdown
---
layout: content
title: What's in the box
eyebrow: OVERVIEW
---

- Bullet one
- Bullet two
- Bullet three
```

Bullets render as Kong-square lime markers via the bundled `style.css`.

## `two-cols`

Use Slidev's named slot markers `::left::` and `::right::`.

```markdown
---
layout: two-cols
title: Before / after
eyebrow: COMPARISON
---

::left::

#### Before

- Manual onboarding
- No telemetry

::right::

#### After

- Self-service portal
- Konnect telemetry
```

## `stats`

Pass an array of `items` in frontmatter. Each item supports `value`, `label`, `note`. The grid auto-arranges:

| Items   | Columns |
|---------|---------|
| 1       | 1       |
| 2       | 2       |
| 3       | 3       |
| 4       | 2 x 2   |
| 5 / 6   | 3 x 2   |

```markdown
---
layout: stats
title: The numbers
eyebrow: AT A GLANCE
items:
  - { value: '700B+', label: 'API calls / month' }
  - { value: '60K+', label: 'Stars' }
  - { value: '100+', label: 'Plugins' }
footer: Trusted by enterprises in 32 industries.
---
```

## `quote`

```markdown
---
layout: quote
attribution: Marco Palladino, CTO, Kong
---

> The next decade of APIs isn't human-to-service.
> It's agent-to-everything.
```

Use the markdown blockquote (`>`) syntax inside this layout - the layout styles it as a Funnel Display pull-quote.

## `image`

```markdown
---
layout: image
title: Konnect dashboard
eyebrow: PRODUCT
src: /kong-globe.png
position: right
---

A single control plane for every gateway, every mesh, every agent.
```

`position: left` flips the image to the left half of the slide. Image gets a 1px lime border and a 12px corner radius.

## `team`

```markdown
---
layout: team
title: Who you'll work with
people:
  - { name: 'Jane Doe', title: 'VP Engineering', image: '/jane.png' }
  - { name: 'John Smith', title: 'Director, Platform' }
---
```

`image` is optional - if omitted, the slot shows an empty olive-green tile. Drop in headshots in `public/` and reference them by `/filename.png`.

## `top-title-two-cols`

Title at the top, two equal columns underneath. Use this (instead of plain
`two-cols`) when the comparison itself needs a single overarching title —
common pattern for architecture decks (before/after, on-prem/cloud,
provider-A/Kong).

```markdown
---
layout: top-title-two-cols
title: Same control plane, different runtimes
eyebrow: ARCHITECTURE
margin: tight
---

:: left ::

#### Konnect (cloud)

- Managed control plane
- SLA-backed (99.999%)

:: right ::

#### Self-managed

- Full CP + DP control
- Air-gap supported
```

## `full`

Full-bleed slide with no header / footer chrome. Designed for hero images,
architecture topology shots, demo screenshots, and overlay annotations
positioned via `v-drag`.

```markdown
---
layout: full
---

<img src="/topology.png" alt="Architecture" />

<KongBox label="Auth boundary" v-drag="[140, 140, 360, 200]" />
<KongArrow :x1="500" :y1="240" :x2="780" :y2="240" />
```

If the only child of the layout is an `<img>`, it auto-fills the canvas
via `object-fit: cover`. Layer Kong components (KongBox, KongArrow,
KongStickyNote) on top with `v-drag="[x, y, w, h]"` for annotations.

## `closing`

```markdown
---
layout: closing
contact: dustin@konghq.com
url: konghq.com
---

# Thank you!
```

The "Thank you!" headline renders huge in lime; `contact` and `url` sit on a lime hairline footer.

---

## Density: the `margin:` prop

Layouts that take a `margin:` prop (`content`, `two-cols`, `top-title-two-cols`)
accept the following values to compress padding for dense slides:

| Value     | Effect                              |
|-----------|-------------------------------------|
| `normal` (default) | Standard 3.5rem / 5rem padding |
| `tight`   | 2rem / 4rem; compressed gap          |
| `tighter` | 1.25rem / 3rem; very compressed      |
| `none`    | 0.5rem / 1rem; near-edge            |

There are also two utility classes you can add to any container inside a
slide for finer-grained control over bullet rhythm:

- `.kong-tight` — closer bullet spacing
- `.kong-tighter` — tighter still

```markdown
---
layout: content
title: A dense slide
margin: tight
---

<div class="kong-tighter">

- Bullet one
- Bullet two
- Bullet three (very tight rhythm)

</div>
```

---

## Components

The Kong theme ships these components in `theme-kong/components/`. Slidev
auto-imports anything in this directory; just use the tag in markdown.

| Component         | Purpose                                                        |
|-------------------|----------------------------------------------------------------|
| `<KongAdmonition>` | Callout box — `info`, `tip`, `warn`, `caution`, `perf`, `security`, `deprecated` |
| `<KongStickyNote>` | Floating note; supports `devOnly` to hide in builds            |
| `<KongArrow>`      | Lime annotation arrow (wraps Slidev's `<Arrow>`)               |
| `<KongBox>`        | Labelled rectangle for highlighting regions of a diagram      |
| `<KongQRCode>`     | Brand-coloured QR code for follow-up links                     |

### `<KongAdmonition>`

```markdown
<KongAdmonition type="perf">
Plugin order matters. Auth → rate-limit → transform is canonical.
</KongAdmonition>
```

`type` accepts: `info` (default), `tip`, `warn`, `caution`, `perf`,
`security`, `deprecated`. Optional `title` appends after the type label
(`PERF — TITLE`). `warn` and `caution` swap to coral accents.

### `<KongStickyNote>`

```markdown
<KongStickyNote title="Aside" width="260px" v-drag="[820, 200, 260, 'auto']">
Anything inside the lime box runs on customer infrastructure.
</KongStickyNote>

<KongStickyNote title="To do" devOnly v-drag="[820, 460, 260, 'auto']">
Replace this hero image with the customer's actual topology before the call.
</KongStickyNote>
```

Props: `title`, `width` (default `240px`), `devOnly`. With `devOnly`, the
note shows in `slidev dev` but disappears from `slidev build` and
`slidev export` — perfect for speaker reminders.

### `<KongArrow>`

Thin wrapper around Slidev's built-in `<Arrow>` with Kong defaults
(lime stroke, width 2). Two-point geometry — give start and end coords,
the component handles the rest.

```markdown
<KongArrow :x1="500" :y1="240" :x2="780" :y2="240" />
<KongArrow :x1="200" :y1="100" :x2="600" :y2="400" two-way :width="3" />
```

Props: `x1`, `y1`, `x2`, `y2` (required), `color` (default lime),
`width` (default 2), `twoWay` (boolean — heads on both ends).

### `<KongBox>`

Labelled rectangle. Position via `v-drag="[x, y, w, h]"`. Use to highlight
a region on an architecture diagram or screenshot.

```markdown
<KongBox label="Auth boundary" v-drag="[140, 140, 360, 200]" />
<KongBox label="Deprecated" tone="warn" v-drag="[600, 300, 220, 150]" />
```

Props: `label` (optional uppercase eyebrow), `tone`: `lime` (default),
`warn` (coral), `muted` (grey).

### `<KongQRCode>`

```markdown
<KongQRCode value="https://docs.konghq.com" caption="Docs" :size="180" />
```

Props: `value` (URL, required), `size` (default 240), `level` (`L`/`M`/`Q`/`H`,
default `M`), `background` / `foreground` (default near-black on lime),
`caption` (optional uppercase label below the code).

---

## Click-staged reveals

Wrap a list (or any container) with `class="kong-fader"` and pair with
`<v-clicks>`. Already-revealed items fade to 35% as new ones appear, so the
active item draws the eye. Useful for layered architecture walk-throughs.

```markdown
<div class="kong-fader">

<v-clicks>

- Edge — TLS terminates at the gateway
- Auth — OIDC / mTLS / API key plugins
- Policy — rate-limit, ACL, transforms
- Routing — service / route match, retries

</v-clicks>

</div>
```

---

## Adding a new layout

1. Create `layouts/<name>.vue` in the deck directory (Slidev picks it up automatically - no registration step).
2. Use Kong tokens from `style.css` (`var(--kong-bg-dark)`, `var(--kong-lime)`, etc.) so it stays on-brand.
3. Reach for `:slotted(...)` selectors in scoped styles to style content that comes from the markdown body.
4. If the layout takes structured data (like `stats.items` or `team.people`), define it as a `defineProps` in the `<script setup>` block.

## Slidev features that work as-is

- **Code blocks** with Shiki highlighting (` ```ts ` etc.) - the bundled `style.css` adapts the surround colors to Kong.
- **Drawings**: `d` key during presentation. Persist with `drawings.persist: true` in the deck frontmatter.
- **Presenter notes**: `<!-- comment -->` immediately after the slide frontmatter.
- **Transitions**: deck-level `transition: fade` is the Kong default. Override per-slide with `transition: slide-left`, etc.
- **Animations**: `<v-click>`, `<v-clicks>`, `<v-after>` work inside any layout.
- **MDC syntax**: enabled via `mdc: true` in the deck frontmatter.

## Export

The bundled `justfile` wraps the pnpm scripts:

```
just install            # one-shot: pnpm install
just dev                # live-reload dev server (slideshow + presenter)
just build              # static HTML to dist/ (web hosting)
just pdf                # export deck.pdf
just pptx               # export deck.pptx (image-flatten -- not editable)
just clean              # remove artifacts + node_modules
```

(Underlying pnpm equivalents: `pnpm install`, `pnpm dev`, `pnpm build`,
`pnpm export-pdf`, `pnpm export-pptx`.)

`just pptx` is fine when the recipient strictly needs a `.pptx` file
(corporate distribution, audiences without browsers). For an **editable**
PPTX where the recipient can change text and shapes, use the
`kong-pptx-build` skill instead — Slidev's PPTX export is one image per
slide.
