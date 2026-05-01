---
name: marp-slides
description: Create MARP presentation decks (Markdown source, PDF / editable PPTX / HTML output) with SVG charts, dashboard components, three themes (neutral dark, neutral light, brand-locked Kong), and 23 reference example decks (22 community + a Kong starter). Triggers ONLY on explicit MARP requests ("marp", "marp deck", ".md slides", "create a marp presentation", "kong marp deck", "marp ebr / qbr"). Do NOT trigger on bare "slides" / "presentation" / "deck" — those belong to kong-pptx-build (Kong-branded PPTX), kong-revealjs-theme (Kong reveal.js), revealjs (general reveal.js), or slidev-generate (Slidev with Kong/Neversink themes).
version: 2.2
updated: 2026-04-30
---

# MARP Slides

Create polished MARP decks. Source is plain Markdown; output is PDF, editable PPTX (real shapes/text), image-flatten PPTX, or interactive HTML.

## When to use this skill (and when NOT)

Use this skill ONLY when the user explicitly asks for MARP, or wants a deck where the *source* must be a single committable `.md` file with one-shot CLI export to multiple formats. For everything else there are better-fitting skills:

| Need | Use |
|---|---|
| Kong-branded customer-facing PPTX (template-driven) | `kong-pptx-build` |
| Kong-branded reveal.js | `kong-revealjs-theme` |
| Generic reveal.js (component-rich HTML deck) | `revealjs` |
| Slidev with Kong or Neversink theme | `slidev-generate` |
| **Markdown-source decks → PDF / editable PPTX in one shot** | **this skill** |

## Prerequisites

Runtime tools are provided by this NixOS module (`modules/apps/cli/claude-code/default.nix`):

- **`marp-cli`** — invoked via `npx @marp-team/marp-cli` (no install needed; npx fetches it).
- **Chromium-based browser** — required for PDF and image-flatten PPTX export. Your system has `google-chrome-stable`. If marp-cli does not auto-detect it, prepend `CHROME_PATH="$(command -v google-chrome-stable)"` to the export command.
- **LibreOffice (`soffice`)** — required for `--pptx-editable` (real editable shapes/text). Provided by the nix module.

Optional editor: **Marp for VS Code** with `markdown.marp.enableHtml: true` and `markdown.marp.allowLocalFiles: true`. Not needed for export — only for live preview.

## Example Decks (CRITICAL — read before generating)

The `examples/` folder contains 23 curated reference decks (22 community + 1 Kong starter). **Before generating any deck, read 2-3 examples that match the requested style.** These are the quality bar — match their composition, spacing, and visual density. Key examples by category:

| Category | Examples to read |
|---|---|
| **Kong / work / customer-facing** | **`marp_kong-starter.md` (REQUIRED reading for any Kong-branded deck)** |
| Data / dashboard | `marp_facebook-ads.md`, `marp_fitness.md`, `marp_comparison.md` |
| Lifestyle / editorial | `marp_coffee.md`, `marp_wine-tasting.md`, `marp_cocktail.md` |
| Guide / how-to | `marp_garden.md`, `marp_houseplant.md`, `marp_home-gym.md` |
| Fun / creative | `marp_kids-party.md`, `marp_board-game.md`, `marp_film-director.md` |
| Travel / location | `marp_travel.md`, `marp_walking-tour.md`, `marp_road-trip.md` |
| Showcase / hero | `marp_hero.md`, `marp_apartment.md`, `marp_wardrobe.md` |
| Reference / sampler | `marp_sample.md` (component showcase) |

## Core Rules

- Slides separated by `---`
- YAML frontmatter controls theme/pagination/styles
- `enableHtml` unlocks SVG, cards, charts, animations, interactive elements
- Default 16:9 (1280x720)

## Dark Starter Template

The dark template uses Outfit 800 for headings and Raleway 100-200 for body text. CSS variables:

```css
@import url('https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700;800&family=Raleway:wght@100;200;300&display=swap');

:root {
  --accent: #ff6b1a; --accent-hover: #ff8c4a;
  --dark: #000; --card: #080808; --border: #111;
  --body: #999; --label: #666; --muted: #555; --light: #fff;
  --green: #22c55e; --red: #ef4444; --yellow: #f5a623;
}
section { background: var(--dark); color: var(--light); font-family: 'Raleway', sans-serif; font-weight: 200; padding: 56px 72px; }
h1 { font-family: 'Outfit'; font-weight: 800; font-size: 3em; color: var(--light); }
h2 { font-family: 'Raleway'; font-weight: 100; font-size: 1.3em; color: #888; }
h3 { font-family: 'Outfit'; font-weight: 600; font-size: 0.6em; color: var(--muted); text-transform: uppercase; letter-spacing: 0.2em; }
strong { color: var(--accent); font-weight: 300; }
section.lead { display: flex; flex-direction: column; justify-content: center; align-items: center; text-align: center; }
header { text-align: right; } header img { margin: 0; }
.row:hover { background: #0c0c0c; } .row { transition: background 0.2s; border-radius: 6px; }
details { background: var(--card); border: 1px solid var(--border); border-radius: 10px; padding: 14px 18px; margin-top: 8px; }
details summary { color: var(--accent); font-family: 'Outfit'; font-weight: 600; font-size: 0.8em; cursor: pointer; }
details p { color: var(--body); font-size: 0.78em; margin-top: 8px; }
.tag { font-family: 'Outfit'; font-weight: 600; font-size: 0.55em; letter-spacing: 0.12em; text-transform: uppercase; padding: 3px 10px; border-radius: 4px; }
abbr { text-decoration: none; border-bottom: 1px dotted #333; cursor: help; }
```

Frontmatter includes: `header: '![w:100](./logo.png)'`

## Light Theme

Swap vars: `--accent: #2563eb; --dark: #fafafa; --card: #fff; --border: #eee; --body: #666; --label: #bbb; --light: #1a1a1a;`
Use Space Grotesk + IBM Plex Mono or Plus Jakarta Sans.

## Kong Theme (work / customer-facing decks)

Use this theme when the deck is **Kong-branded**: customer-facing, internal Kong content, EBR / QBR, technical reviews, anything that ships with the Kong wordmark. Two variants: **dark** (default, near-black) and **light** (warm gray-green). Brand rules below are LOCKED — do not change palette, fonts, footer, or accent usage.

**See the canonical reference deck**: `examples/marp_kong-starter.md`. Read it before generating any Kong-branded deck — match its composition, footer placement, section divider style, and stat-grid density.

### Locked palette

**Dark (default):**
- Background: `#000000`  •  Card fill: `#30352F`  •  Border: `#1f201d`
- Primary text: `#FFFFFF`  •  Secondary text: `#AAB4BB`  •  Muted: `#8A8F89`
- Accent (ONLY accent allowed): `#CCFF00` (Kong neon green)

**Light:**
- Background: `#D7DED4`  •  Card fill: `#42453E` (white text on it)  •  Border: `#bcc2b8`
- Primary text: `#42453E`  •  Secondary text: `#737772`  •  Muted: `#666666`
- Accent: `#CCFF00`

### Locked typography

- Primary: **Funnel Sans** (Regular 400 / Medium 500 / SemiBold 600)
- Hero / cover titles: **Funnel Display** (Bold 700 / Black 800)
- Sparingly: **Urbanist** (display)
- All available on Google Fonts; import via `@import url('https://fonts.googleapis.com/css2?family=Funnel+Display:wght@700;800&family=Funnel+Sans:wght@400;500;600&display=swap');`

| Element | Size | Weight | Notes |
|---|---|---|---|
| Hero title (cover, section) | 60–72pt | Funnel Display 800 | One word in `--accent` |
| Slide title (h1) | 36pt | Funnel Display 700 | |
| Section label (h3) | 9–10pt | Funnel Sans 600 | UPPERCASE, accent color, 0.18em letter-spacing |
| Subtitle (h2) | 22–24pt | Funnel Sans 500 | Muted color |
| Body | 14–16pt | Funnel Sans 400 | Left-aligned only |
| Stats numbers | 48–72pt | Funnel Display 800 | Always accent color |
| Footer | 7–8pt | Funnel Sans 400 | Light/muted |

### Kong dark theme — drop-in frontmatter

```yaml
---
marp: true
theme: default
size: 16:9
paginate: true
header: '![w:36 h:32](./assets/kong/kong-mark-green.png)'
footer: 'AI CONNECTIVITY  ·  © Kong Inc.  ·  CONFIDENTIAL | NOT TO BE SHARED EXTERNALLY'
style: |
  @import url('https://fonts.googleapis.com/css2?family=Funnel+Display:wght@700;800&family=Funnel+Sans:wght@400;500;600&display=swap');
  :root {
    --kong-accent: #CCFF00;
    --kong-bg: #000000;
    --kong-card: #30352F;
    --kong-border: #1f201d;
    --kong-text: #FFFFFF;
    --kong-secondary: #AAB4BB;
    --kong-muted: #8A8F89;
  }
  section {
    background: var(--kong-bg);
    color: var(--kong-text);
    font-family: 'Funnel Sans', sans-serif;
    font-weight: 400;
    padding: 56px 72px 88px;
  }
  h1 { font-family: 'Funnel Display'; font-weight: 700; font-size: 36pt; color: var(--kong-text); margin: 0 0 16px; }
  h2 { font-family: 'Funnel Sans'; font-weight: 500; font-size: 22pt; color: var(--kong-secondary); margin: 0 0 12px; }
  h3 { font-family: 'Funnel Sans'; font-weight: 600; font-size: 9pt; color: var(--kong-accent); text-transform: uppercase; letter-spacing: 0.18em; margin: 0 0 24px; }
  strong { color: var(--kong-accent); font-weight: 600; }
  a { color: var(--kong-accent); }
  ul, ol { font-size: 14pt; line-height: 1.6; }
  li { margin-bottom: 6px; }
  header { right: 56px; top: 28px; }
  footer { left: 72px; right: 72px; bottom: 28px; font-size: 7pt; color: var(--kong-muted); letter-spacing: 0.08em; }
  section::after { color: var(--kong-muted); font-size: 7pt; right: 56px; bottom: 28px; }
  /* Cover / lead slide */
  section.lead { display: flex; flex-direction: column; justify-content: center; padding: 72px 96px; }
  section.lead h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 64pt; line-height: 1.05; color: var(--kong-text); }
  section.lead h2 { font-size: 22pt; color: var(--kong-secondary); }
  section.lead .meta { margin-top: auto; font-size: 10pt; color: var(--kong-muted); letter-spacing: 0.12em; text-transform: uppercase; }
  /* Section divider — last word in green */
  section.section { display: flex; flex-direction: column; justify-content: center; padding: 72px 96px; }
  section.section h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 56pt; line-height: 1.1; max-width: 900px; }
  section.section h1 .accent { color: var(--kong-accent); }
  /* Stats grid */
  .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 32px 48px; }
  .stat .num { font-family: 'Funnel Display'; font-weight: 800; font-size: 56pt; color: var(--kong-accent); line-height: 1; }
  .stat .label { font-size: 11pt; color: var(--kong-secondary); margin-top: 8px; max-width: 280px; }
  /* Numbered steps (1, 2, 3 …) */
  .steps { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 24px; }
  .step .n { font-family: 'Funnel Display'; font-weight: 800; font-size: 36pt; color: var(--kong-accent); line-height: 1; }
  .step h4 { font-family: 'Funnel Sans'; font-weight: 600; font-size: 13pt; margin: 12px 0 6px; }
  .step p { font-size: 11pt; color: var(--kong-secondary); }
  /* Card */
  .card { background: var(--kong-card); border: 1px solid var(--kong-border); border-radius: 4px; padding: 20px 24px; }
  /* Tables — defeat MARP default striping that hides text on dark bg */
  table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 12pt; background: transparent; }
  thead, tbody, tr { background: transparent !important; }
  tbody tr:nth-child(even) { background: rgba(204, 255, 0, 0.04) !important; }
  th { text-align: left; font-family: 'Funnel Sans'; font-weight: 600; font-size: 9pt; color: var(--kong-accent); text-transform: uppercase; letter-spacing: 0.14em; padding: 10px 12px; border-bottom: 1px solid var(--kong-border); background: transparent; }
  td { padding: 10px 12px; border-bottom: 1px solid var(--kong-border); color: var(--kong-secondary); background: transparent; }
  tbody tr td:first-child { color: var(--kong-text); font-weight: 500; }
---
```

### Kong light theme — overrides

Apply on top of the dark frontmatter (or use as a separate deck). Replace the `:root` block with:

```css
:root {
  --kong-accent: #CCFF00;
  --kong-bg: #D7DED4;
  --kong-card: #42453E;       /* dark card on light background */
  --kong-border: #bcc2b8;
  --kong-text: #42453E;
  --kong-secondary: #737772;
  --kong-muted: #666666;
}
```

…and switch the header asset to the dark logo mark: `header: '![w:36 h:32](./assets/kong/kong-mark-dark.png)'`. Card bodies on light theme display white text on `#42453E` — set explicit `color: #FFFFFF` inside `.card`.

### Footer bar (mandatory on content slides)

Every content slide has the footer auto-rendered via the `footer:` frontmatter. To hide it on a single slide (cover, full-bleed), use:

```markdown
<!-- _footer: '' -->
<!-- _header: '' -->
<!-- _paginate: false -->
```

Cover and closing slides MUST hide the footer — the brand wordmark stands alone there.

### Slide patterns

Use `<!-- _class: lead -->` for cover/closing, `<!-- _class: section -->` for section dividers. Examples:

**Cover:**
```markdown
<!-- _class: lead -->
<!-- _footer: '' -->
<!-- _paginate: false -->

# The Unified API and AI Platform

## Customer technical review

<div class="meta">APRIL 2026 · DUSTIN KRYSAK</div>
```

**Section divider (last word in green):**
```markdown
<!-- _class: section -->
<!-- _header: '' -->
<!-- _footer: '' -->
<!-- _paginate: false -->

### Section 02

# Fragmentation drives AI <span class="accent">failure</span>
```

**Stats grid:**
```markdown
### Scale today

# A secure foundation for software development

<div class="stats">
  <div class="stat"><div class="num">100K+</div><div class="label">Active customers</div></div>
  <div class="stat"><div class="num">100TB</div><div class="label">Data processed daily</div></div>
  <div class="stat"><div class="num">99.99%</div><div class="label">Uptime SLA</div></div>
</div>
```

**Numbered steps:**
```markdown
### How it works

# Three phases to value

<div class="steps">
  <div class="step"><div class="n">1</div><h4>Discover</h4><p>Inventory existing APIs and identify governance gaps.</p></div>
  <div class="step"><div class="n">2</div><h4>Govern</h4><p>Apply policies, security, and rate limits at the gateway.</p></div>
  <div class="step"><div class="n">3</div><h4>Operate</h4><p>Observe traffic and iterate on policy in production.</p></div>
</div>
```

### Brand do / don't (LOCKED)

- ✅ One accent only: `#CCFF00`. Use it for: key word in titles, stat numbers, section labels (h3), CTAs, the Kong mark.
- ❌ Never introduce a second accent. No blue, orange, purple "highlights".
- ✅ Funnel Sans / Funnel Display only. Urbanist sparingly.
- ❌ No Arial, Times, Calibri, Helvetica, Roboto, Inter as primary.
- ✅ Left-align body, paragraphs, lists. Center only h1 / h2 on cover and section slides.
- ❌ No underline accents under titles (AI-deck tell).
- ❌ No rounded rectangles with green borders. Cards use `--kong-card` fill, 1px border, 4px radius max.
- ❌ No stock photography. Backgrounds are `--kong-bg` solid or full-bleed branded imagery only.
- ✅ Kong footer bar on every content slide. Hide explicitly on cover / section / closing.
- ✅ Vary layouts: cover → section → stats → content → steps → timeline → closing. Don't stack identical h1+bullets slides.

### Assets shipped with this skill

`assets/kong/` (rsynced into `~/.claude/skills/marp-slides/assets/kong/`):

- `kong-logo-full-green.png` — full logo + "Kong" wordmark in neon green (cover, closing, hero use)
- `kong-mark-green.png` — logo mark only, neon green (header on dark theme)
- `kong-mark-dark.png` — logo mark only, dark/black (header on light theme)

When generating a Kong deck, **copy these assets into the user's deck directory** (e.g. `./assets/kong/...`) on first use — MARP requires relative paths and `--allow-local-files`, and `~/.claude/...` is not portable for the user's deck git repo.

```bash
mkdir -p assets/kong
cp ~/.claude/skills/marp-slides/assets/kong/*.png assets/kong/
```

## Heading Hierarchy

- h1 = title slides (white, extra large)
- h2 = subtitle (grey, thin)
- h3 = section label (muted, uppercase, small)

## Font Pairings (Tested)

| Heading | Body | Use |
|---|---|---|
| Outfit 800 | Raleway 100 | Dashboard, data (default) |
| DM Serif Display | DM Sans 300 | Recipes, editorial |
| Space Grotesk 700 | IBM Plex Mono 300 | Travel, light themes |
| Sora 700 | Sora 200 | Product comparisons |
| Urbanist 800 | Urbanist 100 | Music, Spotify-style |
| Plus Jakarta Sans 800 | Plus Jakarta Sans 200 | Retros, team decks |

## Images

CRITICAL: Relative paths only. `./image.png` works. Absolute paths break in preview.

- Logo header: `header: '![w:100](./logo.png)'` — hide per slide: `<!-- _header: '' -->`
- Photo bg: `![bg brightness:0.15](https://unsplash.com/photo-ID?w=1400)`
- Split: `![bg right:35% brightness:0.2 blur:3px](url)` or `![bg left:30%](url)`
- CDN logos: `<img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/name.png" style="width:200px;" />`
- Centered inline: wrap img in `<div style="display:flex; justify-content:center;">` with border-radius and border

## Dashboard Components

### Metric Card (gradient top border)
Card with `position:relative; overflow:hidden;` and absolute div at top with `background:linear-gradient(90deg, var(--accent), transparent); height:2px;`. Icon + label + big number + trend arrow.

### Status Dots
Inline SVG circles: green (#22c55e) = active, yellow (#f5a623) = learning, red (#ef4444) = paused.
`<svg width="8" height="8" viewBox="0 0 8 8"><circle cx="4" cy="4" r="4" fill="#22c55e"/></svg>`

### Verdict Tags
`<span class="tag" style="background:#22c55e12; color:var(--green); border:1px solid #22c55e22;">Scale</span>`
Swap colors for red (kill) and yellow (review).

### Hover Rows
Wrap content in `<div class="row">` for hover highlight effect.

## SVG Charts

### Line / Area Chart
SVG polyline for the line + polygon with linearGradient fill for area under the line. Add grid lines, dashed target line, circle data points. Use viewBox="0 0 900 240" with preserveAspectRatio="none".

### Pie / Donut Chart
Each segment = separate circle with stroke-dasharray and stroke-dashoffset. Math: circumference = 2*pi*r. For r=110: ~691. Segment = (pct/100)*691. Offsets accumulate negatively. stroke-width controls ring thickness. Always transform="rotate(-90 cx cy)".

### Gauge / Half-Circle Meter
SVG path arc for background + colored value arc. Needle line from center + circle pivot. For scores 0-100. stroke-linecap="round".

### Donut Ring
Single circle stroke-dasharray. circ = 2*pi*r. Offset = circ - (circ * pct/100). For r=74: circ=465. 89%: offset=51.

### Sparkline (inline mini)
`<svg width="50" height="16"><polyline points="0,14 8,12 16,10 24,8 50,2" fill="none" stroke="#22c55e" stroke-width="1.2"/></svg>`

### Stacked Bar
Flex div with colored width-percent segments, border-radius, overflow:hidden.

### Vertical Bar Chart
Flex container align-items:flex-end. Gradient bars: `background:linear-gradient(180deg, var(--accent), #cc5515); border-radius:3px 3px 0 0;`

### Radar / Spider
SVG polygon for hexagonal grid + data shape with fill-opacity:0.1 and stroke outline.

## Interactive Elements

- Collapsible: `<details><summary>Title</summary><p>Content</p></details>`
- Tooltip: `<abbr title="Full text">TERM</abbr>`
- Slider: `<input type="range" style="accent-color:var(--accent);" />`
- Checkbox: `<input type="checkbox" checked style="accent-color:var(--accent);" />`
- Progress: `<progress value="76" max="100" style="accent-color:var(--accent);"></progress>`

## Layout Components

- Before/After Split — two flex panels, border-top red vs green
- Terminal Mockup — traffic light dots + monospace body
- Browser Mockup — dots + URL bar div
- Chat Bubbles — user (left) + agent (right, orange-tinted)
- Flowchart — boxes + SVG arrow connectors
- Timeline — vertical border-left + dot circles
- Card Row — display:flex; gap:14px; with flex:1 children

## SVG Icons

All wrapped in `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--accent)" stroke-width="1.5">`. Sizes: inline=16, cards=44, features=32.

Dollar: path d="M12 2v20M17 5H9.5a3.5 3.5 0 1 0 0 7h5a3.5 3.5 0 1 1 0 7H6"
Heartbeat: polyline points="22 12 18 12 15 21 9 3 6 12 2 12"
Check (#22c55e): path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" + polyline points="22 4 12 14.01 9 11.01"
Arrow up (#22c55e): polyline points="18 15 12 9 6 15"
Arrow down (#ef4444): polyline points="18 9 12 15 6 9"
X circle (#ef4444): circle cx=12 cy=12 r=10 + two crossing lines
Clock: circle cx=12 cy=12 r=10 + polyline points="12 6 12 12 16 14"
Eye: path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" + circle cx=12 cy=12 r=3
Lightning: path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"
Warning (#f5a623): triangle path
Search: circle cx=11 cy=11 r=8 + line to corner
Bars: three vertical paths
Users: user silhouette path + circle
Globe: circle + horizontal line + vertical ellipse path
Lock: rect + arch path
Book: two paths for book shape

## Animations (HTML export + preview only)

float: translateY(0) to -8px and back
glow: box-shadow pulse with accent color
blink: border-color toggle for cursors

Stagger with delay: animation: float 4s ease-in-out 0.5s infinite;

## Export

All commands assume the deck is named `slides.md`. Run from the directory containing the deck so relative image paths resolve.

### HTML (preview-fidelity, keeps animations + `<details>`)

```bash
npx @marp-team/marp-cli slides.md --html --allow-local-files
```

No external dependencies. Best for self-hosted previews and shareable links. Animations and interactive elements only render in HTML output.

### PDF (recommended for read-only distribution)

```bash
npx @marp-team/marp-cli slides.md --pdf --allow-local-files
```

Requires a Chromium-based browser. If marp-cli cannot auto-detect Chrome, force the path:

```bash
CHROME_PATH="$(command -v google-chrome-stable)" npx @marp-team/marp-cli slides.md --pdf --allow-local-files
```

### PPTX — editable (RECOMMENDED for handing decks to humans who'll edit them)

```bash
npx @marp-team/marp-cli slides.md --pptx-editable --allow-local-files
```

Produces a PowerPoint with **real editable text, shapes, and tables**. Requires `soffice` (LibreOffice) on PATH. If you see "soffice: command not found", LibreOffice is missing — verify the nix module shipped it (`which soffice`).

Caveat: complex SVG charts and HTML/CSS effects may not survive the LibreOffice round-trip exactly. Always open the output and check before sending.

### PPTX — image-flatten (fallback only)

```bash
npx @marp-team/marp-cli slides.md --pptx --allow-local-files
```

Each slide becomes a single flat image inside the .pptx. **Not editable.** Only use this when LibreOffice is unavailable or when you need pixel-perfect rendering of complex SVG/CSS that LibreOffice cannot reproduce.

## Design Rules

1. One idea per slide. Overflow clips silently.
2. h1 = white. Accent for data highlights only.
3. Body text #999, labels #666. Never darker than #555.
4. Max 6 rows per list slide.
5. Charts over numbers. Mix visual types across slides.
6. Relative paths only for images.
7. Always preview — no overflow warnings in source.
8. Per-slide overrides: _backgroundColor, _header, _paginate, _footer

Custom dimensions: section { width: 540px; height: 720px; } (CSS not size: frontmatter).
Portrait: stack vertically, scale down 15-20%.
