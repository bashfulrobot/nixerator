# Neversink theme reference

Distilled from the upstream docs at <https://gureckis.github.io/slidev-theme-neversink/>.
When in doubt, fetch the upstream page -- this file is a working summary, not
a replacement.

> **Slidev core features.** Magic Move (animated code transitions),
> `v-clicks` (staged reveals), `v-drag` (free-form positioning), Mermaid
> diagrams, TwoSlash (typed code with hovers), and Slidev's built-in
> components (`<Arrow>`, `<Toc>`, `<Tweet>`, `<Youtube>`, `<AutoFitText>`,
> `<LightOrDark>`, etc.) all work in Neversink decks. They're documented
> in `references/markdown-guide.md` -- the same doc the Kong theme uses.
> Reach for them especially in code-heavy or architecture talks.

- Repo: <https://github.com/gureckis/slidev-theme-neversink>
- Example deck: <https://gureckis.github.io/slidev-theme-neversink/example/#1>
- Author: Todd Gureckis (NYU). Education / academia oriented with whimsical
  components. Component-driven, not just CSS skinning.

## Installation

The theme is an npm package. Two ways to start:

1. **New project** -- `npm init slidev@latest` and pick `neversink` at the prompt.
2. **Existing project** -- add `theme: neversink` to deck-level frontmatter and
   install `slidev-theme-neversink` as a dependency. The bundled `theme-neversink/`
   already does this; running `pnpm install` (or npm/bun) in the scaffolded
   directory pulls the theme.

## Deck-level frontmatter

Set on the FIRST slide only.

```yaml
---
theme: neversink
title: Deck Title
info: |
  ## Deck description
  Markdown rendered in slidev's deck info panel.
colorSchema: auto         # auto | light | dark -- enables Slidev dark mode
neversink_slug: 'My Talk' # appears in the slide-counter footer
transition: fade
mdc: true
---
```

`colorSchema: auto` is recommended -- it follows the OS preference and the
audience can press `d` to toggle. Color schemes (see below) automatically
adapt to dark mode.

## Per-slide frontmatter

```yaml
---
layout: <name>
color: <scheme>           # any colour scheme name (see Colour schemes)
align: <alignment>        # see per-layout alignment grammar
columns: is-6             # for two-column layouts (Bulma sizing: is-3, is-4, ..., is-9)
margin: tight             # normal | tight | tighter | none -- top/side padding
neversink_slug: '...'     # override deck-level slug for this slide
slide_info: false         # hide the slide counter on this slide
---
```

## Layouts

Eleven custom layouts. URLs in the table link to the upstream per-layout pages
which contain visual examples.

| Layout | Purpose | Key frontmatter | Slots |
|--------|---------|-----------------|-------|
| `cover` | Title slide | `color` | default, `:: note ::` |
| `intro` | Intro slide (line under title) | `color` | default, `:: note ::` |
| `default` | Standard body slide | `color`, `margin` | default |
| `top-title` | Title at top, content below | `color`, `align`, `margin` | `:: title ::`, `:: content ::` |
| `top-title-two-cols` | Top title, two columns | `color`, `align`, `columns`, `margin` | `:: title ::`, `:: left ::`, `:: right ::` |
| `two-cols-title` | Title + two columns side-by-side | `color`, `align`, `columns`, `margin` | `:: title ::`, `:: left ::`, `:: right ::` |
| `side-title` | Title on the side | `color`, `align`, `margin` | `:: title ::`, `:: content ::` |
| `quote` | Pull-quote with attribution | `color`, `author`, `quotesize`, `authorsize` | default |
| `section` | Section divider | `color` | default |
| `full` | Full-bleed slide (no chrome) | `color` | default |
| `credits` | Movie-style scrolling credits | `color`, `speed`, `loop` | default |

Standard Slidev layouts (`image-left`, `image-right`, `iframe`, `none`, `end`,
`fact`) still work but DO NOT respect Neversink's `color:` schemes.

### Slot syntax

Slots use `:: name ::` markers. **Blank lines around the marker are
mandatory** -- the markdown preprocessor will not parse content otherwise.

```md
:: title ::

# This is the title

:: content ::

This is the content slot.
```

### Alignment grammar

Layouts that take an `align:` prop use a compact grammar where each region
gets a horizontal-vertical pair. Examples:

- `lt` -- left-aligned, top-aligned
- `cm` -- centre, middle
- `rb` -- right, bottom
- For multi-region layouts (e.g. `two-cols-title`): `l-lt-lt` means
  title-left, left-col-top-left, right-col-top-left.

Refer to the layout's docs page when unsure -- the grammar varies per layout.

### Per-layout details worth knowing

- **`cover` / `intro`** -- both use the default slot for title + author. The
  optional `:: note ::` slot renders smaller text at the bottom (good for
  venue / event line). Default colour is `white`.
- **`quote`** -- attribution prop is `author:` (NOT `quotedBy:`). `quotesize:`
  and `authorsize:` accept Tailwind text-size utilities (`text-2xl`,
  `text-base`, etc.). Default colour is `light`.
- **`credits`** -- `speed:` defaults to `0.5` (higher = faster), `loop:`
  defaults to `false`. Slot expects an HTML grid; see
  `theme-neversink/slides.md` for a working pattern.

## Colour schemes

Apply via `color:` in slide frontmatter. Schemes set CSS custom properties:

```css
--neversink-bg-color
--neversink-bg-code-color
--neversink-fg-code-color
--neversink-fg-color
--neversink-text-color
--neversink-border-color
--neversink-highlight-color
```

### Available schemes

- **Black & white**: `black`, `white`, `dark`, `light`
- **Light**: `red-light`, `orange-light`, `amber-light`, `yellow-light`,
  `lime-light`, `green-light`, `emerald-light`, `teal-light`, `cyan-light`,
  `sky-light`, `blue-light`, `indigo-light`, `violet-light`, `purple-light`,
  `pink-light`, `rose-light`, `fuchsia-light`, `slate-light`, `gray-light`,
  `zinc-light`, `neutral-light`, `stone-light`, `navy-light`
- **Regular**: `red`, `orange`, `amber`, `yellow`, `lime`, `green`, `emerald`,
  `teal`, `cyan`, `sky`, `blue`, `indigo`, `violet`, `purple`, `pink`, `rose`,
  `fuchsia`, `slate`, `gray`, `zinc`, `neutral`, `stone`, `navy`

### Direct class usage

If you need to colour an arbitrary element (outside of the layout system):

```html
<div class="neversink-red-scheme ns-c-bind-scheme">Red box</div>
```

The `ns-c-bind-scheme` class binds:

```css
background-color: var(--neversink-bg-color);
color: var(--neversink-text-color);
border-color: var(--neversink-border-color);
```

Shorthand aliases for the most-used schemes: `ns-c-bk-scheme` (black),
`ns-c-wh-scheme` (white), `ns-c-dk-scheme` (dark), `ns-c-lt-scheme` (light),
`ns-c-nv-scheme` (navy), `ns-c-nv-lt-scheme` (navy-light). For the others
use the first two letters: `ns-c-pi-scheme` for pink, `ns-c-em-scheme` for
emerald, etc.

## Components

Inline Vue components ship with the theme. Most can be dropped straight into
markdown. Many support the `v-drag` directive for arbitrary positioning.

| Component | Purpose |
|-----------|---------|
| `<Admonition>` | Highlighted callout box -- manual props |
| `<AdmonitionType>` | Preset admonition with auto colour + icon |
| `<StickyNote>` | Sticky-note element |
| `<SpeechBubble>` | Speech bubble with shape / position / colour |
| `<QRCode>` | QR code generator |
| `<Kawaii>` | Cute Vue Kawaii character figures |
| `<Email>` | Formatted email address |
| `<ArrowDraw>` | Hand-drawn looking arrow |
| `<ArrowHeads>` | Multiple arrows pointing at a centre |
| `<Thumb>` | Thumb up / down hand |
| `<Line>` | Straight line, no arrowhead |
| `<VDragLine>` | `v-drag` version of Line |
| `<Box>` | Box / rectangle shape |
| `<CreditScroll>` | Movie-style scrolling credits (also exposed via `layout: credits`) |

### Admonitions

```vue
<AdmonitionType type="tip" width="380px">
This is a tip-style admonition.
</AdmonitionType>
```

`type` accepts: `info`, `important`, `tip`, `warning`, `caution`. For full
control use `<Admonition title="..." color="..." width="...">`.

### StickyNote

```vue
<StickyNote color="amber-light" textAlign="left" width="240px" title="Aside" v-drag="[120, 140, 240, 'auto']">
Hello, I'm a sticky note.
</StickyNote>
```

Props: `title`, `color` (default `amber-light`), `width` (default `180px`),
`textAlign` (default `left`), `custom` (CSS class on content), `customTitle`
(CSS class on title), `devOnly` (default `false`). With `devOnly` the note
renders in `slidev dev` but not in `slidev build` / `slidev export` -- great
for speaker reminders.

### `v-drag` positioning

Slidev's `v-drag` directive accepts `[x, y, width, height]` (height can be
`'auto'`). Drag positions can also be edited live in the Slidev editor and
written back to the markdown.

## Markdown extras

- **Highlighted text** -- `==highlighted==` renders as a highlight pass.
- **Inline HTML/CSS** -- works, but **blank lines** must surround any HTML
  block or slot marker, otherwise markdown won't be processed inside.

```md
<div class='something'>

This is **bold** because of the blank lines.

</div>
```

## Styling utilities

The theme exposes UnoCSS utilities prefixed with `ns-c-`:

### Bullet density

- `ns-c-tight` -- closer bullet spacing
- `ns-c-verytight` -- tighter still
- `ns-c-supertight` -- maximum compression

### Slide margins

Frontmatter `margin:` (works on `default`, `full`, `section`, `top-title`,
`top-title-two-cols`, `side-title`, `two-cols-title`):

| Value | Top padding | Side padding |
|-------|-------------|--------------|
| `normal` | 1.8rem | default |
| `tight` | 0.8rem | 1.5rem |
| `tighter` | 0.4rem | 1rem |
| `none` | 0 | 0 |

CSS classes: `ns-c-tight-margin`, `ns-c-tighter-margin`, `ns-c-no-margin`.

### Other utilities

- `ns-c-fader` -- pair with `<v-clicks at="+0">` to fade bullets during
  click progression.
- `ns-c-cite`, `ns-c-cite-bl` -- smaller italic citation; `-bl` pins it
  bottom-left.
- `ns-c-quote` -- bigger italic body for inline quotes.
- `ns-c-iconlink`, `ns-c-plainlink`, `ns-c-nounderline` -- strip default
  link decorations (use for icon links).
- `ns-c-border` -- left border with theme colour, plus margin/padding.
- `ns-c-imgtile` -- image fills its container; pair with grid utilities.
- `ns-c-center-item` -- `margin: auto; width: fit-content`.

UnoCSS utilities (`grid`, `grid-cols-3`, `gap-4`, `flex`, `w-1/3`, etc.) are
available and recommended for ad-hoc layouts.

## Dark mode

`colorSchema: auto` (deck-level) enables Slidev's dark-mode toggle. Audience
keyboard shortcut: `d`. Each colour scheme has light + dark variants and
swaps automatically.

For images that should invert in dark mode:

```html
<img src="/diagram.png" class="invert" />
```

For separate dark / light assets:

```vue
<LightOrDark>
  <template #light><img src="/chart-light.png" /></template>
  <template #dark><img src="/chart-dark.png" /></template>
</LightOrDark>
```

Programmatic access:

```vue
<script setup>
import { isDark, toggleDark } from '@slidev/client/logic/dark'
</script>
```

## Branding (slide footer)

The slide-counter in the lower right shows `current / total` plus an optional
slug.

- **Set deck-level slug** -- `neversink_slug: 'My Talk'` in frontmatter.
- **Override per slide** -- `neversink_slug: '...'` on the slide.
- **Hide on a slide** -- `slide_info: false`.
- **Replace entirely** -- create `slide-bottom.vue` or `global-bottom.vue` in
  the project root (Slidev `custom/global-layers` mechanism).

## Doc page index

When you need depth on a topic, fetch the matching upstream page:

- Layouts overview -- `/slidev-theme-neversink/layouts.html`
- Per-layout pages -- `/slidev-theme-neversink/layouts/{cover,intro,default,top-title,top-title-two-cols,two-cols-title,side-title,quote,section,full,credits}.html`
- Components overview -- `/slidev-theme-neversink/components.html`
- Per-component pages -- `/slidev-theme-neversink/components/{admonitions,email,speechbubble,stickynote,qrcode,kawaii,arrowdraw,arrowheads,thumb,line,vdragline,box}.html`
- Colours -- `/slidev-theme-neversink/colors.html`
- Dark mode -- `/slidev-theme-neversink/dark-mode.html`
- Styling utilities -- `/slidev-theme-neversink/styling.html`
- Markdown extras -- `/slidev-theme-neversink/markdown.html`
- Branding (footer) -- `/slidev-theme-neversink/branding.html`
- Customizing further -- `/slidev-theme-neversink/customizing.html`
