---
name: slidev-generate
description: "Generate a Slidev (sli.dev) deck from one of two bundled themes: Kong (work / customer-facing, lime #CCFF00 on near-black, Funnel Display/Sans typography, Kong wordmarks) or Neversink (personal / community / hobby talks, component-driven, 25+ colour schemes, light + dark, sticky-notes / admonitions / QR / kawaii / drag-positioned widgets). INVOKE ONLY when the user explicitly types `/slidev-generate` -- never auto-trigger from generic deck/slide language; the user has other slide skills (kong-pptx-build, kong-revealjs-theme) that own those auto-triggers. Scaffolds a fresh Slidev project in the target directory by copying the chosen theme, then prints the install/run commands. Output is HTML/PDF; PPTX export is image-flatten only -- for editable PowerPoint use kong-pptx-build instead."
allowed-tools: ["Bash", "Read", "Edit", "Write"]
---

# slidev-generate

Generate a Slidev presentation from one of two bundled themes. Slash-only:
do **not** trigger on generic "make a deck" / "create slides" language --
that lane belongs to `kong-pptx-build` (editable PPTX) and
`kong-revealjs-theme` (reveal.js HTML). Only run when the user types
`/slidev-generate`.

## When to use this skill

Use Slidev (this skill) when the user wants:

- An HTML or PDF deck (not editable PowerPoint).
- Slidev's developer-friendly features: live code blocks with Shiki
  highlighting, MDC, Vue components inside slides, drawings, presenter
  mode, two-column markdown, click-staged reveals.

If they want a `.pptx` they can edit in PowerPoint or Google Slides,
redirect to `kong-pptx-build`. If they want raw reveal.js, redirect to
`kong-revealjs-theme`.

## Themes

The skill ships two themes side-by-side:

| Theme | Path | When to pick |
|-------|------|--------------|
| **Kong** | `theme-kong/` | Work / customer / Kong-branded talks: QBRs, EBRs, customer reviews, internal Kong content. Locked to the Kong brand (palette, typography, wordmarks). |
| **Neversink** | `theme-neversink/` | Personal / community / hobby talks: meetups, conference submissions, hobby projects, anything outside the Kong brand. Light + dark, 25+ colour schemes, component-rich. |

If the user is ambiguous, ask **once**: "Kong-branded (work) or Neversink
(personal/community)?" Default to **Neversink** if they say "personal",
"meetup", "community", "hobby", "talk submission", or anything that's
clearly not Kong work. Default to **Kong** if they say "QBR", "EBR",
"customer", "Konnect", "Kong", "internal".

## What the skill does

When invoked:

1. **Confirm the theme** (Kong vs Neversink). One question, not three.
2. **Confirm the target directory.** Default: current working directory.
   If the directory is non-empty, ask before overwriting.
3. **Copy the bundled theme directory** (`theme-kong/` or
   `theme-neversink/`) into the target directory. For Kong, the `public/`
   subdirectory inside the theme also goes to `<target>/public/`. The
   theme directory ships with a `justfile` so the user has a tidy command
   surface (`just dev`, `just pdf`, etc.) instead of memorising pnpm
   scripts.
4. **Print the install/run commands.**

   ```
   cd <target>
   just install      # one-shot: pnpm install
   just dev          # opens http://localhost:3030
                     # presenter view: http://localhost:3030/presenter/
   ```

   Other recipes available: `just build` (static HTML for web hosting),
   `just pdf` (export deck.pdf), `just pptx` (export deck.pptx —
   image-flatten only; for editable PPTX use `kong-pptx-build`),
   `just clean` (remove artifacts + node_modules). Run `just` with no
   arguments to list them.

5. **Brief on layouts and components.** Point them at the right reference
   doc (see References below).

## Theme-specific notes

### Kong (`theme-kong/`)

Self-contained custom theme -- ships full `style.css` + 22 custom Vue
layouts + brand assets. The layout catalogue mirrors the bundled
`kong-theme.pptx` template: every layout wears the same chrome (corner
registration crosses, inset content frame, three-column footer band) via
the shared `<KongChrome>` component.

```
theme-kong/
├── package.json
├── justfile              # just install / dev / build / pdf / pptx / clean
├── slides.md             # Sample deck demonstrating every layout
├── style.css             # Kong tokens (palette, fonts, bullets, code styling)
├── components/
│   ├── KongChrome.vue        # Shared chrome wrapper used by every layout
│   ├── KongTriangle.vue      # SVG A-frame Kong glyph for footer
│   ├── KongAdmonition.vue    # Callout box (info/tip/warn/perf/security/...)
│   ├── KongArrow.vue         # Lime annotation arrow (wraps Slidev's <Arrow>)
│   ├── KongBox.vue           # Labelled rectangle for diagram regions
│   ├── KongQRCode.vue        # Brand-coloured QR code
│   └── KongStickyNote.vue    # Floating note; supports devOnly
├── layouts/
│   # Core
│   ├── cover.vue                   # Title slide w/ phyllotaxis hero, date pill, speaker
│   ├── section.vue                 # Section divider; phyllotaxis sandwich + statement
│   ├── content.vue                 # Default title + body, optional right-side image
│   ├── closing.vue                 # Oversized "Kong" word + contact band
│   # Information density
│   ├── agenda.vue                  # Numbered agenda (2-4 items) + date pill
│   ├── mission.vue                 # Mission statement + lime left rule
│   ├── numbered-values.vue         # 1-3 numbered cards (principles / values)
│   ├── timeline.vue                # 4-5 step horizontal timeline
│   ├── persona.vue                 # Customer persona card (photo + traits)
│   # Stats / numbers
│   ├── stats.vue                   # 1-6 big numbers; auto column count
│   ├── stats-trio.vue              # 3 stats in a row with category labels
│   ├── hero-stat.vue               # 1 hero stat with intro
│   ├── partnership-stats.vue       # 2 hero stats below headline + intro
│   ├── achievements-mosaic.vue     # Award + market share + quote mosaic
│   ├── comparison-stats.vue        # Bullets left + bar chart right
│   ├── partnership-cards.vue       # 2 / 3 / 4 partnership cards
│   # Multi-column / media
│   ├── two-cols.vue                # ::left:: / ::right:: named slots
│   ├── top-title-two-cols.vue      # Title across top + two columns
│   ├── image.vue                   # Text + image, image left or right
│   ├── quote.vue                   # Big lime quote mark, attribution + role
│   ├── team.vue                    # Headshot grid 3/4/6 columns based on count
│   └── full.vue                    # Full canvas; bleed mode drops the inset
└── public/
    ├── kong-logo.png            # Kong mark + wordmark, lime
    ├── kong-konnect.png         # Kong Konnect lockup
    ├── kong-globe.png           # Decorative globe
    ├── kong-blades-tall.png     # Phyllotaxis hero (cover backdrop)
    ├── kong-blades-wide.png     # Phyllotaxis band (section dividers)
    ├── kong-blades-orbit.png    # Phyllotaxis orbit (corner decoration)
    └── kong-glow.png            # Soft lime glow texture
```

**Deck-level chrome configuration** -- set in the first slide's
frontmatter (cascades through `$slidev.configs`):

```yaml
kong_category: AI CONNECTIVITY
kong_copyright: 'Kong Inc. 2026'
kong_external: 'NOT TO BE SHARED EXTERNALLY'
```

Per-slide override: pass `category:` to any layout to swap that slide's
footer category.

**Ground rules**

- **Do not modify** `style.css` colours or font stack to fit a customer's
  preference -- the palette is locked to the Kong brand. If they need a
  different look, redirect them to the Neversink theme.
- **Match the PPTX.** The 22 bundled layouts mirror the slide bases in
  the bundled `kong-theme.pptx` template. Add new ones to
  `theme-kong/layouts/` only when the user names a real gap.
- **New layouts must wrap with `<KongChrome>`** so they inherit the
  corner crosses + footer band.

### Neversink (`theme-neversink/`)

Thin scaffold around the upstream `slidev-theme-neversink` npm package
(Todd Gureckis, NYU). The theme itself comes from npm at install time;
this directory ships only the deck-level entry points.

```
theme-neversink/
├── package.json          # Adds slidev-theme-neversink as a dep
└── slides.md             # Sample deck demonstrating layouts + components
```

**Ground rules**

- **The theme is npm-managed.** Don't try to vendor or modify Vue layout
  files -- updates come through `pnpm update slidev-theme-neversink`.
- **Customise via frontmatter and CSS variables**, not by editing the
  package. See `references/neversink.md` for the documented surface.
- **Brand customisation:** logo / footer / fonts are added via the
  consuming project (custom `slide-bottom.vue` or `global-bottom.vue`,
  `:root` CSS overrides). Don't fork the theme.

Eleven custom layouts ship with Neversink (`cover`, `intro`, `default`,
`top-title`, `top-title-two-cols`, `two-cols-title`, `side-title`,
`quote`, `section`, `full`, `credits`) plus thirteen components
(`<Admonition>`, `<AdmonitionType>`, `<StickyNote>`, `<SpeechBubble>`,
`<QRCode>`, `<Kawaii>`, `<Email>`, `<ArrowDraw>`, `<ArrowHeads>`,
`<Thumb>`, `<Line>`, `<VDragLine>`, `<Box>`). 25+ colour schemes apply
per slide via `color: <scheme>` frontmatter; light + dark variants are
automatic.

## Workflow

1. **Pick the theme** -- ask if not obvious.
2. **Confirm target directory** -- default to cwd; ask before clobbering
   non-empty directories.
3. **Copy the theme.** From `~/.claude/skills/slidev-generate/<theme-dir>/`
   into `<target>/`. For Kong, `public/` becomes `<target>/public/`.
4. **Print install / run commands** (see above).
5. **Point at references.**

   - Kong: `references/layouts-kong.md` (per-layout shape contract).
   - Neversink: `references/neversink.md` (layouts, components, colour
     schemes, styling utilities, dark mode, branding).
   - Both: `references/markdown-guide.md` (Slidev markdown / authoring).

## Authoring conventions

- **Notes go in HTML comments** (`<!-- ... -->`) immediately after the
  slide's frontmatter, per Slidev convention.
- **Slot markers need blank lines around them** -- Slidev's markdown
  preprocessor will not parse content inside `:: name ::` slots otherwise.
- **PPTX export caveat:** Slidev's `--format pptx` produces a deck of
  pre-rendered images per slide (text not selectable, no editable shapes).
  This is documented at sli.dev/guide/exporting and is a Slidev limitation,
  not something to fight. For editable PPTX use `kong-pptx-build`.

## References

Local reference files (always available offline):

- `references/markdown-guide.md` -- general Slidev syntax, layouts, slots,
  code blocks, transitions.
- `references/layouts-kong.md` -- per-layout shape contract for the Kong
  theme (props, slots, intended use).
- `references/neversink.md` -- distilled Neversink docs: layouts,
  components, colour schemes, styling utilities, dark mode, footer
  customisation, plus the upstream URL index for deeper dives.

Upstream (when local refs are insufficient):

- Slidev: <https://sli.dev/>
- Neversink: <https://gureckis.github.io/slidev-theme-neversink/>
- Neversink example deck: <https://gureckis.github.io/slidev-theme-neversink/example/#1>

## Sources

**Kong theme** -- design tokens were derived from `kong-theme.pptx` (the
same bundled template used by `kong-pptx-build`):

- Palette: tallied SRGB values across `ppt/slides/*.xml`,
  `ppt/slideMasters/slideMaster1.xml`, `ppt/slideLayouts/*.xml`. Top usage:
  `#CCFF00` (lime, 431 uses), `#001408` (master background), `#AAB4BB`
  (mid grey), `#273216` (dark olive), `#000000`.
- Typefaces: extracted from `<a:latin typeface="...">` references. Funnel
  Display, Funnel Sans (Light/Medium/SemiBold/Bold), Space Grotesk,
  Urbanist. Funnel Display and Funnel Sans load via Google Fonts.
- Wordmarks and hero asset: `ppt/media/image12.png`, `image24.png`,
  `image1.png`.

**Neversink theme** -- consumed unmodified from npm
(`slidev-theme-neversink`). Reference doc transcribed from upstream pages
on the gureckis.github.io site (2026-04-30).
