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

**See the canonical reference deck**: `examples/marp_kong-starter.md`. Read it before generating any Kong-branded deck — it demonstrates every layout class. Match its composition, footer placement, section divider style, and stat-grid density.

The theme is engineered to match the official Kong PowerPoint template (2026 dark). The set below covers every layout pattern in that template — cover variants, section dividers, agenda, stats, steps, timelines, team grids, partner cards, dashboards. Use these classes; do not invent new ones unless the user asks.

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
| Hero title (cover, section) | 48–72pt | Funnel Display 800 | One word in `--accent` |
| Slide title (h1) | 36pt | Funnel Display 700 | |
| Section label (h3) | 9–10pt | Funnel Sans 600 | UPPERCASE, accent color, 0.18em letter-spacing |
| Subtitle (h2) | 22–24pt | Funnel Sans 500 | Muted color |
| Body | 14–16pt | Funnel Sans 400 | Left-aligned only |
| Stats numbers | 48–72pt | Funnel Display 800 | Always accent color |
| Footer | 8pt | Funnel Sans 400 / 600 | Branded band |

### Kong dark theme — drop-in frontmatter (comprehensive)

This frontmatter ships every layout class. Copy verbatim, then build slides using the patterns documented under "Slide patterns".

```yaml
---
marp: true
theme: default
size: 16:9
paginate: true
footer: '<span class="fleft">![w:16 h:14](./assets/kong/kong-mark-green.png)AI CONNECTIVITY</span><span class="fmid">© Kong Inc.</span>'
style: |
  @import url('https://fonts.googleapis.com/css2?family=Funnel+Display:wght@700;800&family=Funnel+Sans:wght@400;500;600&display=swap');
  :root {
    --kong-accent: #CCFF00;
    --kong-bg: #000000;
    --kong-card: #0e110d;
    --kong-card-strong: #1a1d18;
    --kong-border: #1f201d;
    --kong-text: #FFFFFF;
    --kong-secondary: #AAB4BB;
    --kong-muted: #8A8F89;
  }
  section { background: var(--kong-bg); color: var(--kong-text); font-family: 'Funnel Sans', sans-serif; font-weight: 400; padding: 56px 72px 80px; position: relative; }
  /* Corner registration marks — brand pattern (subtle "L" at four corners) */
  section::before {
    content: ''; position: absolute; top: 18px; left: 18px; right: 18px; bottom: 56px; pointer-events: none; z-index: 0;
    background:
      linear-gradient(var(--kong-accent), var(--kong-accent)) top left / 14px 1px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) top left / 1px 14px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) top right / 14px 1px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) top right / 1px 14px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) bottom left / 14px 1px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) bottom left / 1px 14px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) bottom right / 14px 1px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) bottom right / 1px 14px no-repeat;
  }
  section > * { position: relative; z-index: 1; }
  h1 { font-family: 'Funnel Display'; font-weight: 700; font-size: 36pt; color: var(--kong-text); margin: 0 0 16px; line-height: 1.15; }
  h2 { font-family: 'Funnel Sans'; font-weight: 500; font-size: 22pt; color: var(--kong-secondary); margin: 0 0 12px; }
  h3 { font-family: 'Funnel Sans'; font-weight: 600; font-size: 9pt; color: var(--kong-accent); text-transform: uppercase; letter-spacing: 0.18em; margin: 0 0 24px; }
  h4 { font-family: 'Funnel Sans'; font-weight: 600; font-size: 14pt; margin: 12px 0 6px; color: var(--kong-text); }
  strong { color: var(--kong-accent); font-weight: 600; }
  a { color: var(--kong-accent); }
  ul, ol { font-size: 14pt; line-height: 1.65; padding-left: 1.2em; }
  li { margin-bottom: 8px; }
  li::marker { color: var(--kong-accent); }
  code { background: var(--kong-card-strong); color: var(--kong-text); padding: 1px 6px; border-radius: 3px; font-size: 0.9em; word-break: break-word; overflow-wrap: anywhere; }
  /* Branded footer band (replicates the PPTX template footer) */
  footer { left: 0; right: 0; bottom: 0; height: 38px; padding: 0 24px; background: #000; border-top: 1px solid var(--kong-accent); display: flex; align-items: center; font-family: 'Funnel Sans'; font-size: 8pt; letter-spacing: 0.18em; z-index: 2; }
  footer .fleft { color: var(--kong-accent); display: inline-flex; align-items: center; gap: 8px; flex: 0 0 auto; margin-right: 28px; font-weight: 600; }
  footer .fleft img { margin: 0; vertical-align: middle; }
  footer .fmid { color: var(--kong-secondary); flex: 1 1 auto; }
  footer .fright { color: var(--kong-secondary); flex: 0 0 auto; margin-right: 56px; }
  section::after { right: 24px; bottom: 12px; color: var(--kong-secondary); font-family: 'Funnel Sans'; font-size: 8pt; letter-spacing: 0.12em; z-index: 3; }
  /* Cover / lead split layout (title-left, blade-right) */
  section.lead { padding: 0; background: var(--kong-bg); }
  section.lead::before { content: none; }
  section.lead .cover { position: absolute; inset: 0; display: grid; grid-template-columns: 1fr 1fr; }
  section.lead .cover-left { padding: 56px 56px 96px; background: #000; display: flex; flex-direction: column; justify-content: space-between; position: relative; }
  section.lead .cover-left::before { content: ''; position: absolute; top: 32px; left: 32px; right: 32px; bottom: 80px; pointer-events: none;
    background:
      linear-gradient(var(--kong-accent), var(--kong-accent)) top left / 16px 1px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) top left / 1px 16px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) top right / 16px 1px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) top right / 1px 16px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) bottom left / 16px 1px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) bottom left / 1px 16px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) bottom right / 16px 1px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) bottom right / 1px 16px no-repeat;
  }
  section.lead .cover-right { background: url('./assets/kong/kong-blades-tall.png') center / cover no-repeat, #000; }
  section.lead .wordmark { z-index: 2; }
  section.lead .wordmark img { width: 150px; }
  section.lead .title-block { z-index: 2; }
  section.lead h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 48pt; line-height: 1.05; color: var(--kong-text); margin: 0 0 18px; }
  section.lead h2 { font-family: 'Funnel Display'; font-weight: 700; font-size: 18pt; color: var(--kong-text); margin: 0 0 6px; }
  section.lead h2 .accent { color: var(--kong-accent); }
  section.lead .subtitle { font-size: 12pt; color: var(--kong-secondary); margin: 0 0 24px; max-width: 380px; }
  section.lead .meta-row { display: flex; gap: 24px; align-items: center; font-size: 9pt; letter-spacing: 0.2em; text-transform: uppercase; }
  section.lead .meta-date { color: var(--kong-accent); font-weight: 600; }
  section.lead .meta-team { color: var(--kong-secondary); }
  /* Co-branded cover variant — logo bar at top + speaker headshot bottom */
  section.lead-cobrand .logo-bar { display: flex; gap: 0; align-items: center; margin-bottom: 24px; }
  section.lead-cobrand .logo-bar > div { padding: 18px 28px; display: flex; align-items: center; }
  section.lead-cobrand .logo-bar .kong-cell { background: #000; }
  section.lead-cobrand .logo-bar .partner-cell { background: var(--kong-card); margin-left: 1px; color: var(--kong-text); font-family: 'Funnel Display'; font-weight: 800; font-size: 18pt; letter-spacing: 0.04em; }
  section.lead-cobrand .speaker { display: flex; align-items: center; gap: 16px; margin-top: auto; }
  section.lead-cobrand .speaker .avatar { width: 56px; height: 56px; border-radius: 50%; background: var(--kong-accent); display: flex; align-items: center; justify-content: center; font-family: 'Funnel Display'; font-weight: 800; color: #000; font-size: 18pt; }
  section.lead-cobrand .speaker .info .name { font-weight: 600; font-size: 14pt; color: var(--kong-text); }
  section.lead-cobrand .speaker .info .role { font-size: 9pt; letter-spacing: 0.18em; text-transform: uppercase; color: var(--kong-accent); margin-top: 2px; }
  /* Closing — massive Kong wordmark */
  section.lead-closing { padding: 0; background: var(--kong-bg); display: grid; grid-template-rows: auto 1fr; }
  section.lead-closing::before { content: none; }
  section.lead-closing .top { padding: 48px 64px 24px; display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 32px; }
  section.lead-closing .top h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 36pt; color: var(--kong-text); margin: 0; }
  section.lead-closing .top .ready h3 { color: var(--kong-accent); margin: 0 0 4px; font-size: 14pt; letter-spacing: 0; text-transform: none; }
  section.lead-closing .top .ready p { color: var(--kong-secondary); font-size: 11pt; margin: 0; }
  section.lead-closing .top .contact { font-size: 10pt; color: var(--kong-text); line-height: 1.5; }
  section.lead-closing .top .contact a { color: var(--kong-accent); }
  section.lead-closing .wordmark-mega { display: flex; align-items: center; justify-content: center; padding: 0 32px 48px; }
  section.lead-closing .wordmark-mega span { font-family: 'Funnel Display'; font-weight: 800; font-size: 360pt; line-height: 0.85; color: var(--kong-accent); letter-spacing: -0.04em; }
  /* Section dividers */
  section.section { padding: 0; background: var(--kong-bg); }
  section.section::before { content: none; }
  section.section .divider { position: absolute; inset: 0; background: url('./assets/kong/kong-blades-wide.png') right center / cover no-repeat, #000; }
  section.section .divider-content { position: absolute; top: 0; left: 0; right: 50%; bottom: 0; padding: 72px 72px 96px; display: flex; flex-direction: column; justify-content: center; background: linear-gradient(90deg, #000 0%, #000 70%, rgba(0,0,0,0.4) 100%); z-index: 2; }
  section.section h3 { color: var(--kong-accent); font-size: 10pt; letter-spacing: 0.2em; margin-bottom: 24px; }
  section.section h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 44pt; line-height: 1.1; max-width: 100%; }
  /* Section divider — full-bleed (top + bottom blade strips) */
  section.section-fullbleed { padding: 0; background: var(--kong-bg); }
  section.section-fullbleed::before { content: none; }
  section.section-fullbleed .strip-top, section.section-fullbleed .strip-bottom { position: absolute; left: 0; right: 0; height: 30%; background: url('./assets/kong/kong-blades-wide.png') center / cover no-repeat; }
  section.section-fullbleed .strip-top { top: 0; }
  section.section-fullbleed .strip-bottom { bottom: 0; transform: scaleY(-1); }
  section.section-fullbleed .body { position: absolute; left: 64px; right: 64px; top: 30%; bottom: 30%; display: flex; flex-direction: column; justify-content: center; padding: 16px 32px; background: rgba(0,0,0,0.85); }
  section.section-fullbleed h3 { color: var(--kong-accent); font-size: 10pt; letter-spacing: 0.2em; margin-bottom: 20px; }
  section.section-fullbleed h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 38pt; line-height: 1.15; }
  /* Section divider — inverted (lime fill + dark inset card) */
  section.section-inverted { background: var(--kong-accent); }
  section.section-inverted::before { content: none; }
  section.section-inverted .inset { position: absolute; inset: 18% 12% 18% 8%; background: #000; padding: 48px 56px; display: flex; flex-direction: column; justify-content: center; z-index: 2; }
  section.section-inverted h3 { color: var(--kong-accent); font-size: 9pt; letter-spacing: 0.2em; margin-bottom: 18px; }
  section.section-inverted h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 30pt; line-height: 1.2; color: var(--kong-text); }
  /* Agenda — orbit blade left + numbered card list right */
  section.agenda { padding: 0; }
  section.agenda::before { content: none; }
  section.agenda .layout { position: absolute; inset: 0; display: grid; grid-template-columns: 1fr 1.5fr; }
  section.agenda .left { padding: 64px 56px 96px; background: #000 url('./assets/kong/kong-blades-orbit.png') -40px 60% / 360px no-repeat; display: flex; flex-direction: column; justify-content: center; }
  section.agenda .left h3 { color: var(--kong-accent); font-size: 10pt; letter-spacing: 0.2em; margin-bottom: 16px; }
  section.agenda .left h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 36pt; color: var(--kong-text); }
  section.agenda .right { padding: 56px 64px 96px; display: flex; flex-direction: column; justify-content: center; }
  /* Agenda timeline — quarterly cards under blade strips */
  section.agenda-timeline { padding: 0; }
  section.agenda-timeline::before { content: none; }
  section.agenda-timeline .strip-top { position: absolute; top: 0; left: 0; right: 0; height: 28%; background: url('./assets/kong/kong-blades-wide.png') right center / cover no-repeat; }
  section.agenda-timeline .strip-bottom { position: absolute; bottom: 38px; left: 0; right: 0; height: 18%; background: url('./assets/kong/kong-blades-wide.png') left center / cover no-repeat; transform: scaleY(-1); }
  section.agenda-timeline .heading { position: absolute; top: 56px; left: 64px; z-index: 3; }
  section.agenda-timeline .heading h3 { color: var(--kong-accent); }
  section.agenda-timeline .heading h1 { color: var(--kong-text); font-family: 'Funnel Display'; font-weight: 800; }
  section.agenda-timeline .qcards { position: absolute; left: 48px; right: 48px; top: 32%; display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; z-index: 3; }
  section.agenda-timeline .qcard { background: var(--kong-card-strong); padding: 20px 22px; }
  section.agenda-timeline .qcard .n { font-family: 'Funnel Display'; font-weight: 800; font-size: 24pt; color: var(--kong-accent); line-height: 1; }
  section.agenda-timeline .qcard h4 { font-size: 13pt; margin: 12px 0 8px; }
  section.agenda-timeline .qcard p { font-size: 10pt; color: var(--kong-secondary); line-height: 1.5; }
  /* Agenda card list (numbered with horizontal dividers) */
  .agenda-grid { display: grid; grid-template-columns: 1fr; margin-top: 12px; border-top: 1px solid var(--kong-border); }
  .agenda-row { display: grid; grid-template-columns: 56px 1fr; align-items: center; padding: 14px 0; border-bottom: 1px solid var(--kong-border); }
  .agenda-row .num { font-family: 'Funnel Display'; font-weight: 800; font-size: 18pt; color: var(--kong-accent); line-height: 1; }
  .agenda-row .text { font-size: 13pt; color: var(--kong-text); font-weight: 400; }
  /* Stats grid — 3 across or 3×2 (use .stats-6 wrapper for 6-cell) */
  .accent { color: var(--kong-accent); }
  .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 32px 48px; margin-top: 24px; }
  .stats-6 { display: grid; grid-template-columns: repeat(3, 1fr); grid-template-rows: repeat(2, 1fr); gap: 28px 40px; margin-top: 24px; }
  .stat .num { font-family: 'Funnel Display'; font-weight: 800; font-size: 48pt; color: var(--kong-accent); line-height: 1; }
  .stat .label { font-size: 11pt; color: var(--kong-secondary); margin-top: 8px; max-width: 280px; line-height: 1.4; }
  .stat .body { font-size: 10pt; color: var(--kong-muted); margin-top: 6px; }
  /* Spotlight stats (middle card lime-filled) */
  .stat-spotlight { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0; }
  .stat-spotlight .stat { padding: 28px 24px; background: var(--kong-card); }
  .stat-spotlight .stat.hi { background: var(--kong-accent) !important; color: #000 !important; }
  .stat-spotlight .stat.hi .num, .stat-spotlight .stat.hi .label, .stat-spotlight .stat.hi .body, .stat-spotlight .stat.hi h4, .stat-spotlight .stat.hi p, .stat-spotlight .stat.hi strong { color: #000 !important; }
  .stat-spotlight .stat .num { font-size: 44pt; }
  /* Steps / values (numbered cards) */
  .steps { display: grid; grid-template-columns: repeat(3, 1fr); gap: 32px; margin-top: 24px; }
  .steps.cols-2 { grid-template-columns: 1fr 1fr; }
  .steps.cols-4 { grid-template-columns: repeat(4, 1fr); }
  .step { background: transparent; }
  .step .n { font-family: 'Funnel Display'; font-weight: 800; font-size: 36pt; color: var(--kong-accent); line-height: 1; }
  .step h4 { font-family: 'Funnel Sans'; font-weight: 600; font-size: 14pt; margin: 12px 0 6px; color: var(--kong-text); }
  .step p { font-size: 11pt; color: var(--kong-secondary); line-height: 1.5; }
  /* Numbered timeline (circles + dashed line) */
  .timeline-numbered { margin-top: 36px; position: relative; }
  .timeline-numbered .track { display: grid; grid-template-columns: repeat(var(--n, 5), 1fr); align-items: center; position: relative; }
  .timeline-numbered .track::before { content: ''; position: absolute; left: 6%; right: 6%; top: 50%; height: 0; border-top: 1.5px dashed var(--kong-accent); }
  .timeline-numbered .node { width: 48px; height: 48px; border-radius: 50%; border: 1.5px solid var(--kong-accent); display: flex; align-items: center; justify-content: center; font-family: 'Funnel Display'; font-weight: 800; color: var(--kong-accent); font-size: 18pt; background: #000; margin: 0 auto; position: relative; z-index: 1; }
  .timeline-numbered .node.active { background: var(--kong-accent); color: #000; }
  .timeline-numbered .body { display: grid; grid-template-columns: repeat(var(--n, 5), 1fr); gap: 16px; margin-top: 24px; padding: 24px 0; border-top: 1px solid var(--kong-border); border-bottom: 1px solid var(--kong-border); }
  .timeline-numbered .body .step h5 { font-size: 12pt; color: var(--kong-accent); font-family: 'Funnel Sans'; font-weight: 600; margin: 0 0 4px; }
  .timeline-numbered .body .step p { font-size: 10pt; color: var(--kong-secondary); line-height: 1.5; }
  .timeline-numbered .labels { display: grid; grid-template-columns: repeat(var(--n, 5), 1fr); margin-top: 14px; gap: 16px; }
  .timeline-numbered .labels .label { font-size: 9pt; letter-spacing: 0.18em; text-transform: uppercase; color: var(--kong-accent); font-weight: 600; }
  .timeline-numbered .labels .label.pill { background: var(--kong-accent); color: #000; padding: 4px 16px; border-radius: 999px; display: inline-block; justify-self: start; }
  /* Quarter-card timeline (4 cards, no circles) */
  .timeline { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-top: 28px; }
  .ms .label { font-family: 'Funnel Sans'; font-weight: 600; font-size: 8pt; color: var(--kong-accent); text-transform: uppercase; letter-spacing: 0.14em; margin-bottom: 8px; }
  .ms h5 { font-family: 'Funnel Sans'; font-weight: 600; font-size: 12pt; margin: 0 0 6px; color: var(--kong-text); }
  .ms p { font-size: 10pt; color: var(--kong-secondary); line-height: 1.5; }
  /* Cards (generic) */
  .card { background: var(--kong-card); border: 1px solid var(--kong-border); border-radius: 4px; padding: 20px 24px; }
  .card p, .card li { color: var(--kong-text); }
  .card strong { color: var(--kong-accent); }
  .two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
  /* Team grid (headshot + name + title) */
  .team-grid { display: grid; gap: 1px; background: var(--kong-border); margin-top: 20px; }
  .team-grid.cols-3 { grid-template-columns: repeat(3, 1fr); }
  .team-grid.cols-6 { grid-template-columns: repeat(6, 1fr); }
  .team-grid.rows-2 { grid-auto-rows: 1fr; }
  .team-cell { background: var(--kong-card); padding: 18px; display: flex; flex-direction: column; justify-content: flex-end; min-height: 140px; }
  .team-cell .avatar { width: 52px; height: 52px; border-radius: 50%; background: var(--kong-accent); margin-bottom: 12px; display: flex; align-items: center; justify-content: center; font-family: 'Funnel Display'; font-weight: 800; color: #000; font-size: 16pt; }
  .team-cell .name { font-family: 'Funnel Display'; font-weight: 700; font-size: 13pt; color: var(--kong-accent); margin: 0; }
  .team-cell .title { font-size: 10pt; color: var(--kong-secondary); margin: 4px 0 0; }
  /* Partner cards (logo circle + body + CTA) */
  .partner-cards { display: grid; grid-template-columns: repeat(var(--n, 4), 1fr); gap: 18px; margin-top: 24px; }
  .partner-cards .pcard { background: var(--kong-card-strong); padding: 22px 22px 26px; border-radius: 2px; }
  .partner-cards .pcard .logo { width: 80px; height: 28px; border: 1px solid var(--kong-border); border-radius: 999px; display: flex; align-items: center; justify-content: center; font-size: 8pt; color: var(--kong-secondary); letter-spacing: 0.14em; margin-bottom: 16px; }
  .partner-cards .pcard h4 { font-family: 'Funnel Display'; font-weight: 700; font-size: 16pt; color: var(--kong-accent); margin: 0 0 4px; }
  .partner-cards .pcard .meta { font-size: 10pt; color: var(--kong-text); font-weight: 600; margin: 0 0 12px; }
  .partner-cards .pcard p { font-size: 10pt; color: var(--kong-secondary); line-height: 1.5; margin: 0 0 16px; }
  .partner-cards .pcard .cta { display: inline-flex; align-items: center; gap: 8px; padding: 8px 18px; background: var(--kong-accent); color: #000; font-weight: 600; font-size: 10pt; border-radius: 999px; text-decoration: none; }
  /* Label + statement + bullets + accent bar (a hugely common content variant) */
  .label-statement { display: grid; grid-template-columns: 1.4fr 1fr; gap: 48px; }
  .label-statement .left h3 { color: var(--kong-accent); }
  .label-statement .left h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 32pt; line-height: 1.15; }
  .label-statement .left ul { margin-top: 18px; padding-left: 0; list-style: none; }
  .label-statement .left ul li { position: relative; padding-left: 26px; font-size: 12pt; color: var(--kong-secondary); margin-bottom: 8px; line-height: 1.5; }
  .label-statement .left ul li::before { content: ''; position: absolute; left: 0; top: 8px; width: 10px; height: 10px; background: var(--kong-accent); }
  .label-statement .left ul li::marker { content: none; }
  .label-statement code { background: var(--kong-card-strong); color: var(--kong-text); padding: 1px 6px; border-radius: 3px; font-size: 0.92em; }
  .label-statement .right { padding-left: 16px; border-left: 1px solid var(--kong-accent); }
  .label-statement .right p { font-size: 11pt; color: var(--kong-secondary); line-height: 1.6; }
  /* Split: image left, body right (and reverse) */
  .split-image { display: grid; grid-template-columns: 1fr 1fr; gap: 32px; align-items: center; margin-top: 16px; }
  .split-image.reverse { direction: rtl; } .split-image.reverse > * { direction: ltr; }
  .split-image .media { background: var(--kong-card-strong); height: 360px; display: flex; align-items: center; justify-content: center; color: var(--kong-muted); font-size: 10pt; }
  .split-image .media.blade { background: url('./assets/kong/kong-blades-tall.png') center / cover no-repeat; }
  /* Tables — defeat MARP default striping that hides text on dark bg */
  table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 12pt; background: transparent; }
  thead, tbody, tr { background: transparent !important; }
  thead tr { background: rgba(204, 255, 0, 0.10) !important; }
  tbody tr:nth-child(even) { background: rgba(204, 255, 0, 0.04) !important; }
  th { text-align: left; font-family: 'Funnel Sans'; font-weight: 600; font-size: 9pt; color: var(--kong-accent); text-transform: uppercase; letter-spacing: 0.14em; padding: 12px; border-bottom: 2px solid var(--kong-accent); background: transparent; }
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
  --kong-card-strong: #2c2e2a;
  --kong-border: #bcc2b8;
  --kong-text: #42453E;
  --kong-secondary: #737772;
  --kong-muted: #666666;
}
```

Card bodies on light theme display white text on `#42453E` — set explicit `color: #FFFFFF` inside `.card`. The blade imagery does not change.

### Branded footer band (mandatory on content slides)

The `footer:` frontmatter renders as a horizontal black band with a green top border. Three regions:

- **Left** — Kong mark icon + "AI CONNECTIVITY" in neon green (always)
- **Centre** — "© Kong Inc."
- **Right** — page number (auto-rendered by MARP via `section::after`)

Cover, section dividers, and the closing slide MUST hide it explicitly:

```markdown
<!-- _footer: '' -->
<!-- _paginate: false -->
```

### Slide patterns

The classes below mirror the official PPTX template's layout set. Apply with `<!-- _class: <name> -->` at the top of each slide.

#### `lead` — split cover (default opening slide)

```markdown
<!-- _class: lead -->
<!-- _paginate: false -->

<div class="cover">
  <div class="cover-left">
    <div class="wordmark">

![](./assets/kong/kong-logo-full-green.png)

</div>
    <div class="title-block">

# Presentation title

## <span class="accent">Kong</span> Konnect

<p class="subtitle">The Unified API and AI Platform</p>

<div class="meta-row">
  <div class="meta-date">April 2026</div>
  <div class="meta-team">Customer Success</div>
</div>

</div>
  </div>
  <div class="cover-right"></div>
</div>
```

#### `lead-cobrand` — co-branded cover (Kong + partner logo bar, speaker headshot)

```markdown
<!-- _class: lead lead-cobrand -->
<!-- _paginate: false -->

<div class="cover">
  <div class="cover-left">
    <div class="logo-bar">
      <div class="kong-cell">

![w:90](./assets/kong/kong-logo-full-green.png)

</div>
      <div class="partner-cell">GSK</div>
    </div>

# Presentation title

<div class="speaker">
  <div class="avatar">DK</div>
  <div class="info">
    <div class="name">Speaker Name</div>
    <div class="role">Position</div>
  </div>
</div>

  </div>
  <div class="cover-right"></div>
</div>
```

#### `lead-closing` — Thank-you slide with massive Kong wordmark

```markdown
<!-- _class: lead-closing -->
<!-- _paginate: false -->
<!-- _footer: '' -->

<div class="top">
  <h1>Thank you!</h1>
  <div class="ready">

### Ready for what's next?

<p>Let's talk</p>

</div>
  <div class="contact">
Kong Inc.<br>
<a href="mailto:contact@konghq.com">contact@konghq.com</a><br>
44 Montgomery Street<br>
San Francisco, CA 9410, USA<br><br>
<a href="https://konghq.com">Konghq.com</a>
  </div>
</div>
<div class="wordmark-mega"><span>Kong</span></div>
```

#### `section` — half-bleed divider (blade right, statement left)

```markdown
<!-- _class: section -->
<!-- _footer: '' -->
<!-- _paginate: false -->

<div class="divider"></div>
<div class="divider-content">

### Section 01

# Start simple, evolve <span class="accent">gradually</span>

</div>
```

#### `section-fullbleed` — top + bottom blade strips, centered statement

```markdown
<!-- _class: section-fullbleed -->
<!-- _footer: '' -->
<!-- _paginate: false -->

<div class="strip-top"></div>
<div class="strip-bottom"></div>
<div class="body">

### Section title

# Write a bold, compelling statement about what the next section will <span class="accent">communicate.</span>

</div>
```

#### `section-inverted` — lime fill with dark inset card

```markdown
<!-- _class: section-inverted -->
<!-- _footer: '' -->
<!-- _paginate: false -->

<div class="inset">

### Our mission

# Write a bold, compelling statement about what the company wants to achieve.

</div>
```

#### `agenda` — orbit blade left + numbered card list right

```markdown
<!-- _class: agenda -->

<div class="layout">
  <div class="left">

### Agenda

# January '26

</div>
  <div class="right">
    <div class="agenda-grid">
      <div class="agenda-row"><div class="num">1</div><div class="text">Add section title</div></div>
      <div class="agenda-row"><div class="num">2</div><div class="text">Add section title</div></div>
      <div class="agenda-row"><div class="num">3</div><div class="text">Add section title</div></div>
      <div class="agenda-row"><div class="num">4</div><div class="text">Add section title</div></div>
    </div>
  </div>
</div>
```

#### `agenda-timeline` — quarterly cards with blade strips

```markdown
<!-- _class: agenda-timeline -->

<div class="strip-top"></div>
<div class="strip-bottom"></div>
<div class="heading">

### Agenda

# Timeline

</div>
<div class="qcards">
  <div class="qcard"><div class="n">1</div><h4>Quarter, Year</h4><p>Outline the next steps of the partnership plan.</p></div>
  <div class="qcard"><div class="n">2</div><h4>Quarter, Year</h4><p>Set a deadline for drafting an agreement.</p></div>
  <div class="qcard"><div class="n">3</div><h4>Quarter, Year</h4><p>Deliver the implementation plan.</p></div>
  <div class="qcard"><div class="n">4</div><h4>Quarter, Year</h4><p>Allocate resources and decide on channels.</p></div>
</div>
```

#### `.stats` and `.stats-6` — stat grids (3-up or 3×2)

```markdown
### Section label

# A secure foundation for <span class="accent">software</span> development

<div class="stats-6">
  <div class="stat"><div class="num">100,000</div><div class="label">Galaxy astronaut nebula the orbit Comet blackhole supernova</div></div>
  <div class="stat"><div class="num">100TB</div><div class="label">Telemetry processed per month</div></div>
  <div class="stat"><div class="num">99.99%</div><div class="label">Control-plane availability YTD</div></div>
  <div class="stat"><div class="num">+80K</div><div class="label">Routes governed by central policy</div></div>
  <div class="stat"><div class="num">120M</div><div class="label">Daily API requests at peak</div></div>
  <div class="stat"><div class="num">&lt;10ms</div><div class="label">P99 added latency at the gateway</div></div>
</div>
```

#### `.stat-spotlight` — three stats with middle highlighted on lime

```markdown
<div class="stat-spotlight">
  <div class="stat"><div class="num">+80K</div><div class="label">Routes governed by central policy</div></div>
  <div class="stat hi"><div class="num">+120M</div><h4>Daily API requests</h4><p>Galaxy astronaut nebula the orbit</p></div>
  <div class="stat"><div class="num">&lt;10ms</div><div class="label">P99 added latency</div></div>
</div>
```

#### `.steps` — numbered cards (1-up to 4-up via cols-N modifier)

```markdown
### How it works

# Three phases to value

<div class="steps">
  <div class="step"><div class="n">1</div><h4>Discover</h4><p>Inventory existing APIs and identify governance gaps.</p></div>
  <div class="step"><div class="n">2</div><h4>Govern</h4><p>Apply policies, security, and rate limits at the gateway.</p></div>
  <div class="step"><div class="n">3</div><h4>Operate</h4><p>Observe traffic and iterate on policy in production.</p></div>
</div>
```

For 2 columns use `<div class="steps cols-2">`, for 4 use `cols-4`.

#### `.timeline-numbered` — circles + dashed line + descriptions + quarter labels

```markdown
# How the partnership will work

<div class="timeline-numbered" style="--n: 5;">
  <div class="track">
    <div class="node active">1</div>
    <div class="node">2</div>
    <div class="node">3</div>
    <div class="node">4</div>
    <div class="node">5</div>
  </div>
  <div class="body">
    <div class="step"><h5>Step or milestone</h5><p>Outline how the partnership will grow.</p></div>
    <div class="step"><h5>Step or milestone</h5><p>Include shared goals or deadlines.</p></div>
    <div class="step"><h5>Step or milestone</h5><p>Add another example.</p></div>
    <div class="step"><h5>Step or milestone</h5><p>Discuss joint initiatives.</p></div>
    <div class="step"><h5>Step or milestone</h5><p>Add as many steps as you need.</p></div>
  </div>
  <div class="labels">
    <div class="label pill">January</div>
    <div class="label">February</div>
    <div class="label">March</div>
    <div class="label">April</div>
    <div class="label">May</div>
  </div>
</div>
```

#### `.timeline` — 4 quarter-cards (lighter than `.timeline-numbered`)

```markdown
<div class="timeline">
  <div class="ms"><div class="label">Q2 · Apr</div><h5>Discovery complete</h5><p>Full inventory…</p></div>
  <div class="ms"><div class="label">Q2 · May</div><h5>Pilot in staging</h5><p>Two services migrated…</p></div>
  <div class="ms"><div class="label">Q2 · Jun</div><h5>Production cutover</h5><p>Pilot services live.</p></div>
  <div class="ms"><div class="label">Q3 · Jul</div><h5>Policy plane GA</h5><p>Centralised AI-safety.</p></div>
</div>
```

#### `.team-grid` — headshot + name + title (cols-3 or cols-6)

```markdown
# Meet the <span class="accent">team</span>

<div class="team-grid cols-3 rows-2">
  <div class="team-cell"><div class="avatar">DK</div><p class="name">Full Name</p><p class="title">Title</p></div>
  <div class="team-cell"><div class="avatar">JS</div><p class="name">Full Name</p><p class="title">Title</p></div>
  <div class="team-cell"><div class="avatar">MR</div><p class="name">Full Name</p><p class="title">Title</p></div>
  <div class="team-cell"><div class="avatar">AC</div><p class="name">Full Name</p><p class="title">Title</p></div>
  <div class="team-cell"><div class="avatar">TL</div><p class="name">Full Name</p><p class="title">Title</p></div>
  <div class="team-cell"><div class="avatar">EP</div><p class="name">Full Name</p><p class="title">Title</p></div>
</div>
```

For the 12-cell layout from the PPTX, use `cols-6 rows-2`.

#### `.partner-cards` — partnership cards (logo, title, body, CTA)

```markdown
# Our successful <span class="accent">partnerships</span>

<div class="partner-cards" style="--n: 4;">
  <div class="pcard">
    <div class="logo">LOGO</div>
    <h4>Partnership 1</h4>
    <p class="meta">Quarter, Year</p>
    <p>Introduce one of your current partners. Mention their industry and what you accomplished together.</p>
    <a class="cta" href="#">Learn more →</a>
  </div>
  <!-- repeat 3 more cards -->
</div>
```

For the 2-card variant set `style="--n: 2;"` and write fuller copy.

#### `.label-statement` — section label + bold statement + bullets + accent-bar paragraph

```markdown
<div class="label-statement">
  <div class="left">

### The challenge

# Fragmentation drives <span class="accent">AI failure</span>

<ul>
<li>Multiple gateways for REST, gRPC, GraphQL, and now LLM traffic</li>
<li>No unified policy plane for security and compliance</li>
<li>Vendor lock-in by accident — every LLM integrated app-by-app</li>
</ul>

  </div>
  <div class="right">
    <p>Explain how a partnership would help make this goal a reality and why it's worth pursuing together. Think about how your potential partner can contribute.</p>
  </div>
</div>
```

#### `.split-image` — image-half + body-half

```markdown
<div class="split-image">
  <div class="media blade"></div>
  <div>

### Section label

# Title with <span class="accent">accent</span>

Body paragraph that lives next to the image. Keep it under 4 lines.

</div>
</div>
```

Add `.reverse` to swap sides: `<div class="split-image reverse">`.

### Brand do / don't (LOCKED)

- ✅ One accent only: `#CCFF00`. Use it for: key word in titles, stat numbers, section labels (h3), CTAs, the Kong mark.
- ❌ Never introduce a second accent. No blue, orange, purple "highlights".
- ✅ Funnel Sans / Funnel Display only. Urbanist sparingly.
- ❌ No Arial, Times, Calibri, Helvetica, Roboto, Inter as primary.
- ✅ Left-align body, paragraphs, lists. Center only h1 / h2 on cover and section slides.
- ❌ No underline accents under titles (AI-deck tell).
- ❌ No rounded rectangles with green borders. Cards use `--kong-card` fill, 1px border, 4px radius max.
- ❌ No stock photography. Backgrounds are `--kong-bg` solid or full-bleed branded imagery only (the bundled blade PNGs).
- ✅ Kong footer band on every content slide. Hide explicitly on cover / section / closing.
- ✅ Vary layouts: cover → section → stats → content → steps → timeline → closing. Don't stack identical h1+bullets slides.

### Assets shipped with this skill

`assets/kong/`:

- `kong-logo-full-green.png` — full Kong logo + wordmark in neon green (cover, closing, hero)
- `kong-mark-green.png` — logo mark only, neon green (footer left)
- `kong-mark-dark.png` — logo mark only, dark/black (light theme footer)
- `kong-blades-tall.png` — vertical-fan green blade abstract (cover right panel, split-image)
- `kong-blades-wide.png` — horizontal-fan blade abstract (section dividers, agenda timeline strips)
- `kong-blades-orbit.png` — radial blade abstract (agenda left panel)

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
