# Layout reference -- Kong theme

The Kong theme matches the bundled `kong-theme.pptx` brand template. Every layout wears the same chrome (corner registration crosses, inset content frame, three-column footer band) via the shared `<KongChrome>` component. Setting `layout: <name>` in slide frontmatter is all that's required.

## Deck-level chrome configuration

Add these to the **first slide's** frontmatter (or any slide's; they cascade through `$slidev.configs`) to control the footer band on every slide:

```yaml
kong_category: AI CONNECTIVITY               # eyebrow text in the footer
kong_copyright: 'Kong Inc. 2026'             # centre of the footer
kong_external: 'NOT TO BE SHARED EXTERNALLY' # right-side footer caption
```

Per-slide override: pass a `category:` prop to any layout to swap just that slide's footer category.

## Layout catalogue

| Layout                  | Purpose                                              | Key frontmatter                                                  |
|-------------------------|------------------------------------------------------|------------------------------------------------------------------|
| `cover`                 | Deck cover with phyllotaxis hero                     | top-level `product`, `tagline`, `date`, `speaker`               |
| `section`               | Section divider; phyllotaxis sandwich + statement    | `eyebrow`                                                        |
| `agenda`                | Agenda with 2-4 numbered items + date pill           | `title`, `eyebrow`, `date`, `items: [{title,note}]`              |
| `content`               | Default title + body, optional right-side image      | `title`, `eyebrow`, `margin`, `image`, `imageAlt`, `category`    |
| `mission`               | Mission/principle statement with lime left rule      | `eyebrow`, `statement` (supports `**accent**`), `body`          |
| `stats`                 | 1-6 big-number grid                                  | `title`, `eyebrow`, `intro`, `footer`, `items`                   |
| `stats-trio`            | 3 stats in a row with category labels                | `title`, `eyebrow`, `intro`, `items: [{label,value,note}]`       |
| `hero-stat`             | Single hero stat with intro on the left              | `title`, `eyebrow`, `intro`, `value`, `label`, `note`            |
| `numbered-values`       | 2-3 numbered cards (principles, values, pillars)     | `title`, `eyebrow`, `intro`, `items: [{title,body}]`             |
| `achievements-mosaic`   | Award + market-share + quote mosaic                  | `title`, `eyebrow`, `award`, `share`, `quote`                    |
| `partnership-stats`     | Headline + intro + 2 hero stats                      | `title`, `eyebrow`, `intro`, `items: [{value,label,note}]`       |
| `persona`               | Customer persona with photo, demographics, needs     | `title`, `name`, `image`, `quote`, `demographics`, `needs`, `channels` |
| `partnership-cards`     | 2 / 3 / 4 partnership cards                          | `title`, `eyebrow`, `intro`, `items: [{label,metric,title,body}]` |
| `timeline`              | 4-5 step horizontal timeline                         | `title`, `eyebrow`, `intro`, `items: [{label,title,body}]`       |
| `comparison-stats`      | Bullets left + bar chart right                       | `title`, `eyebrow`, `intro`, `bullets`, `bars: [{label,value,display,highlight}]` |
| `two-cols`              | Two-column markdown                                  | `title`, `eyebrow`, `margin`; `::left::` / `::right::` slots     |
| `top-title-two-cols`    | Title across top + two columns below                 | `title`, `eyebrow`, `intro`, `margin`; `::left::` / `::right::` slots |
| `image`                 | Side-by-side text + image with caption               | `title`, `eyebrow`, `src`, `alt`, `caption`, `position`          |
| `quote`                 | Pull-quote with big lime quote mark                  | `attribution`, `role`                                            |
| `team`                  | Headshot grid (3 / 4 / 6 columns)                    | `title`, `eyebrow`, `people: [{name,title,image}]`               |
| `full`                  | Full canvas; optional bleed (no chrome)              | `bleed`, `hideFooter`, `category`                                |
| `closing`               | "Thank you" + oversized "Kong" word                  | `cta`, `ctaSub`, `contact`, `address`, `url`                     |

---

## `cover`

Phyllotaxis hero on the right (loaded from `/kong-blades-tall.png`), title typeset on a dark inset, lime date pill + speaker name in a band below.

```markdown
---
layout: cover
product: Konnect
tagline: One platform for every API, every AI agent, every developer.
date: APRIL 2026
speaker: Dustin Krysak, Staff Technical CSM
---

# Kong Slidev<br/>Brand Theme
```

Title slot accepts a single `<h1>`; keep to two short lines for best fit. `product` reads as `Kong <Product>` in lime above the tagline.

## `section`

Phyllotaxis bands top + bottom (flipped) framing one bold statement in the middle band. `_word_` italics render the wrapped text in lime. `**word**` bold also renders lime.

```markdown
---
layout: section
eyebrow: WHY THIS MATTERS
---

# Connect every API. Every AI agent. _Every developer._
```

One sentence per divider.

## `agenda`

Numbered agenda items (01, 02, 03...) split across one or two columns automatically. Phyllotaxis-orbit decoration at the bottom-right unless `hideOrbit: true`.

```markdown
---
layout: agenda
title: Today
eyebrow: AGENDA
date: APR 30
items:
  - { title: 'Where APIs are headed', note: 'AI agents change the connective tissue' }
  - { title: 'The Konnect platform', note: 'Single control plane, every runtime' }
  - { title: 'Customer outcomes', note: 'Numbers, stories, recognition' }
  - { title: 'Get started', note: 'Resources and next steps' }
---
```

Items can be plain strings (no note) or `{title, note}` objects. 1-2 items render in one column; 3-4 split into two.

## `content`

The 80% layout. Title at top, body below. Pass `image:` to render a right-side image alongside the body.

```markdown
---
layout: content
title: What's in the box
eyebrow: OVERVIEW
image: /kong-globe.png
imageAlt: Konnect topology
---

- Bullet one
- Bullet two
- Bullet three
```

Bullets render as Kong-square lime markers. `**word**` inside body renders lime.

## `mission`

A bold mission/principle statement framed by a 4px lime left rule, with optional supporting paragraph below a hairline.

```markdown
---
layout: mission
eyebrow: MISSION
statement: Make every connection between **services**, **AI agents**, and **developers** secure, observable, and fast.
body: We build the connective tissue that lets enterprises ship faster without trading away governance, performance, or trust.
---
```

`**word**` inside `statement` renders lime. The default eyebrow is "Mission" -- override with `eyebrow:`.

## `stats`

Large-number grid auto-arranged by item count.

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
title: The numbers behind **the platform**
eyebrow: AT A GLANCE
items:
  - { value: '700B+', label: 'API calls / month', note: 'Across customer infrastructure.' }
  - { value: '60K+', label: 'Stars' }
  - { value: '100+', label: 'Plugins' }
footer: Trusted by enterprises in 32 industries.
---
```

`**word**` inside `title:` renders lime.

## `stats-trio`

Three stats with category labels, each cell has a subtle lime corner glow.

```markdown
---
layout: stats-trio
title: The platform in **three numbers**
eyebrow: SCALE
intro: Customer-reported telemetry across the fleet during the trailing twelve months.
items:
  - { value: '700B+', label: 'API calls / month', note: 'Plane-of-record traffic' }
  - { value: '99.999%', label: 'SLA', note: 'Konnect cloud control plane' }
  - { value: '<5ms', label: 'P99 latency', note: 'Per-request gateway overhead' }
footer: Source -- aggregated customer telemetry.
---
```

## `hero-stat`

One hero number with intro paragraph on the left. Phyllotaxis-orbit decoration in the top-right.

```markdown
---
layout: hero-stat
title: One number that **says it all**
eyebrow: SCALE
intro: Across our customer base, the Kong fleet handles more than two-thirds of a trillion API calls in a typical month.
label: API calls processed
value: 700B+
note: Trailing 12 months, customer-reported.
---
```

## `numbered-values`

Numbered cards (01, 02, 03) for principles, pillars, or values. 1-3 columns based on item count.

```markdown
---
layout: numbered-values
title: Three principles
eyebrow: HOW WE BUILD
intro: Every product decision rolls up to one of these three.
items:
  - { title: 'Open by default', body: 'Every commercial product has an open-source core that customers can run, fork, and audit.' }
  - { title: 'Performance first', body: 'Latency budgets and throughput targets are non-negotiable.' }
  - { title: 'Connective tissue', body: 'We do not own the endpoints. We make every endpoint reachable, governable, and observable.' }
---
```

## `achievements-mosaic`

Award + market-share + customer quote in a 2x2 mosaic (quote spans two rows on the right).

```markdown
---
layout: achievements-mosaic
title: Where the industry has placed us
eyebrow: RECOGNITION
award:
  label: 'Gartner MQ'
  name: 'Leader, API Management 2025'
  note: '7th consecutive year.'
share:
  label: 'Open-source share'
  value: '74%'
  note: 'Of public GitHub gateway forks reference Kong.'
quote:
  body: 'Kong is the gateway we benchmark every other gateway against.'
  attribution: 'CTO, Fortune 100 financial services'
---
```

## `partnership-stats`

Two hero stats below a headline + intro. Stat cells have alternating subtle lime corner glow.

```markdown
---
layout: partnership-stats
title: What partnership with Kong **looks like**
eyebrow: WORKING TOGETHER
intro: Customers who deploy with our solutions team see consistent gains.
items:
  - { value: '4x', label: 'Faster onboarding', note: 'Average POC to production' }
  - { value: '63%', label: 'Lower TCO', note: 'vs. self-built alternatives' }
footer: Source -- Forrester TEI commissioned study, 2025.
---
```

## `persona`

Customer persona card: photo + quote on the left, demographics / needs / channels blocks on the right.

```markdown
---
layout: persona
title: Platform Engineer
name: 'Priya, Staff Platform Engineer'
eyebrow: WHO BUYS THIS
image: '/priya.png'
quote: 'I do not want to be the bottleneck.'
demographics:
  - '8-15 years experience'
  - 'Reports to VP Engineering'
needs:
  - 'Self-service onboarding'
  - 'Centralized policy and observability'
channels:
  - 'GitHub, KubeCon, Hacker News'
  - 'Direct from peers'
---
```

## `partnership-cards`

2-4 cards, each with optional `label`, `metric`, `title`, and `body`. 2 cards = 1 row; 3 = 1 row; 4 = 2x2.

```markdown
---
layout: partnership-cards
title: Four ways customers engage
eyebrow: ENGAGEMENT MODELS
intro: Every customer chooses the model that fits their delivery cadence.
items:
  - { label: 'Self-serve', metric: '14d', title: 'Konnect free tier', body: 'Sign up, install a data plane, route real traffic.' }
  - { label: 'Standard', metric: '60d', title: 'Konnect Plus', body: 'Production support, multi-region, audit-ready logs.' }
  - { label: 'Enterprise', metric: '90d', title: 'Konnect Enterprise', body: 'Dedicated CSM, custom SLAs.' }
  - { label: 'Strategic', metric: 'Custom', title: 'Joint roadmap', body: 'Quarterly executive review.' }
---
```

## `timeline`

4-5 step horizontal timeline with numbered nodes (01, 02, ...) connected by a lime gradient track.

```markdown
---
layout: timeline
title: A typical rollout
eyebrow: HOW IT GOES
intro: Phased rollouts let app teams adopt at their own pace while the platform team stays in control.
items:
  - { label: 'Week 0',    title: 'Discovery',    body: 'Map current gateways and traffic.' }
  - { label: 'Week 2',    title: 'Pilot',        body: 'Two services behind Konnect.' }
  - { label: 'Week 6',    title: 'Production',   body: 'Critical path traffic migrated.' }
  - { label: 'Week 12',   title: 'Self-service', body: 'App teams onboarding solo.' }
  - { label: 'Quarter 2', title: 'AI plane',     body: 'Agent-aware policy enforcement.' }
---
```

## `comparison-stats`

Bullets and intro on the left, a horizontal-bar chart on the right. Bars accept `value` (0-100), `display` (the label to show, e.g. `−38%`), and optional `highlight: true` for the lime accent fill.

```markdown
---
layout: comparison-stats
title: Before vs. after **on a single chart**
eyebrow: THE DIFFERENCE
intro: Customers who consolidate gateway sprawl see immediate gains.
bullets:
  - 'Time from change-merge to production cut by half'
  - 'Audit and compliance evidence collected automatically'
  - 'P99 latency improved on most workloads'
bars:
  - { label: 'Latency p99', value: 92, display: '−38%', highlight: true }
  - { label: 'TTM',         value: 76, display: '−54%', highlight: true }
  - { label: 'Headcount',   value: 41, display: '−22%' }
  - { label: 'Cost',        value: 88, display: '−63%', highlight: true }
footer: Source -- Forrester TEI commissioned study, 2025.
---
```

To replace the chart with a custom visual, slot in your own viz:

```markdown
---
layout: comparison-stats
title: Custom chart
bullets: ['One', 'Two']
---

::viz::

<MyCustomChart />
```

## `two-cols`

Use Slidev's named slot markers `::left::` and `::right::`. A 1px lime divider runs between the columns.

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

## `top-title-two-cols`

Same as `two-cols` but with an optional `intro:` paragraph below the title. Use this when the comparison itself needs a single overarching title.

```markdown
---
layout: top-title-two-cols
title: Same control plane, different runtimes
eyebrow: ARCHITECTURE
intro: Customers deploy Konnect in cloud or self-managed mode -- the surface stays identical.
margin: tight
---

::left::

#### Konnect (cloud)

- Managed control plane

::right::

#### Self-managed

- Full CP + DP control
```

## `image`

Text on one side, image on the other. Optional `caption:` shows a lime caption below the image.

```markdown
---
layout: image
title: Konnect dashboard
eyebrow: PRODUCT
src: /kong-globe.png
caption: KONNECT, JUNE 2026
position: right
---

A single control plane for every gateway, every mesh, every agent.
```

`position: left` flips the image to the left half of the slide.

## `quote`

Big lime opening-quote glyph, oversized Funnel Display body text, attribution + role on a hairline footer.

```markdown
---
layout: quote
attribution: Marco Palladino
role: CTO, Kong
---

> The next decade of APIs isn't human-to-service. It's agent-to-everything,
> and the connective tissue has to be **governed, observable, and fast**.
```

`**word**` and `_word_` inside the blockquote render lime.

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

`image` is optional. Auto columns: 3 for ≤3 people, 4 for 4, 6 for 5+.

## `full`

Full canvas slide. Default keeps the chrome (corner crosses + footer band); set `bleed: true` to drop the inset frame and fill the entire canvas, and `hideFooter: true` to remove the footer band entirely.

```markdown
---
layout: full
bleed: true
hideFooter: true
---

<img src="/topology.png" alt="Architecture" />

<KongBox label="Auth boundary" v-drag="[140, 140, 360, 200]" />
<KongArrow :x1="500" :y1="240" :x2="780" :y2="240" />
```

If the only child of the layout is an `<img>` (with `bleed: true`), it auto-fills the canvas via `object-fit: cover`. Layer `<KongBox>`, `<KongArrow>`, `<KongStickyNote>` on top with `v-drag="[x, y, w, h]"` for annotations.

## `closing`

```markdown
---
layout: closing
cta: "Ready for what's next?"
ctaSub: "Let's talk"
contact: dustin@konghq.com
url: konghq.com
---
```

The "Thank you!" headline + lime CTA stack across the top; an oversized lime "Kong" word fills the canvas below. Optional `address` (HTML allowed) and `company` props for the contact block.

---

## Density: the `margin:` prop

Layouts that take a `margin:` prop (`content`, `two-cols`, `top-title-two-cols`) accept the following values to compress padding for dense slides:

| Value     | Effect                              |
|-----------|-------------------------------------|
| `normal` (default) | Standard padding              |
| `tight`   | ~30% less padding                   |
| `tighter` | ~50% less padding                   |
| `none`    | Near-edge                           |

There are also two utility classes you can add to any container inside a slide for finer-grained bullet rhythm:

- `.kong-tight` -- closer bullet spacing
- `.kong-tighter` -- tighter still

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

The Kong theme ships these components in `theme-kong/components/`. Slidev auto-imports anything in this directory; just use the tag in markdown.

| Component         | Purpose                                                        |
|-------------------|----------------------------------------------------------------|
| `<KongChrome>`     | Wrapper used internally by every layout (corner crosses + footer band) |
| `<KongTriangle>`   | Small SVG A-frame Kong glyph                                    |
| `<KongAdmonition>` | Callout box -- `info`, `tip`, `warn`, `caution`, `perf`, `security`, `deprecated` |
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

`type` accepts: `info` (default), `tip`, `warn`, `caution`, `perf`, `security`, `deprecated`. Optional `title` appends after the type label (`PERF -- TITLE`). `warn` and `caution` swap to coral accents.

### `<KongStickyNote>`

```markdown
<KongStickyNote title="Aside" width="260px" v-drag="[820, 200, 260, 'auto']">
Anything inside the lime box runs on customer infrastructure.
</KongStickyNote>

<KongStickyNote title="To do" devOnly v-drag="[820, 460, 260, 'auto']">
Replace this hero image with the customer's actual topology before the call.
</KongStickyNote>
```

Props: `title`, `width` (default `240px`), `devOnly`. With `devOnly`, the note shows in `slidev dev` but disappears from `slidev build` and `slidev export` -- perfect for speaker reminders.

### `<KongArrow>`

Thin wrapper around Slidev's built-in `<Arrow>` with Kong defaults (lime stroke, width 2). Two-point geometry -- give start and end coords, the component handles the rest.

```markdown
<KongArrow :x1="500" :y1="240" :x2="780" :y2="240" />
<KongArrow :x1="200" :y1="100" :x2="600" :y2="400" two-way :width="3" />
```

Props: `x1`, `y1`, `x2`, `y2` (required), `color` (default lime), `width` (default 2), `twoWay` (boolean -- heads on both ends).

### `<KongBox>`

Labelled rectangle. Position via `v-drag="[x, y, w, h]"`. Use to highlight a region on an architecture diagram or screenshot.

```markdown
<KongBox label="Auth boundary" v-drag="[140, 140, 360, 200]" />
<KongBox label="Deprecated" tone="warn" v-drag="[600, 300, 220, 150]" />
```

Props: `label` (optional uppercase eyebrow), `tone`: `lime` (default), `warn` (coral), `muted` (grey).

### `<KongQRCode>`

```markdown
<KongQRCode value="https://docs.konghq.com" caption="Docs" :size="180" />
```

Props: `value` (URL, required), `size` (default 240), `level` (`L`/`M`/`Q`/`H`, default `M`), `background` / `foreground` (default near-black on lime), `caption` (optional uppercase label below the code).

---

## Click-staged reveals

Wrap a list (or any container) with `class="kong-fader"` and pair with `<v-clicks>`. Already-revealed items fade to 35% as new ones appear, so the active item draws the eye. Useful for layered architecture walk-throughs.

```markdown
<div class="kong-fader">

<v-clicks>

- Edge -- TLS terminates at the gateway
- Auth -- OIDC / mTLS / API key plugins
- Policy -- rate-limit, ACL, transforms
- Routing -- service / route match, retries

</v-clicks>

</div>
```

---

## Adding a new layout

1. Create `layouts/<name>.vue` in `theme-kong/layouts/` (Slidev picks it up automatically -- no registration step).
2. Wrap content with `<KongChrome :category="category">` so it inherits the chrome.
3. Use Kong tokens from `style.css` (`var(--kong-bg-dark)`, `var(--kong-lime)`, etc.) so it stays on-brand.
4. Reach for `:slotted(...)` selectors in scoped styles to style content that comes from the markdown body.
5. If the layout takes structured data (like `stats.items` or `team.people`), define it as `defineProps` in the `<script setup>` block.

## Slidev features that work as-is

- **Code blocks** with Shiki highlighting (` ```ts ` etc.) -- the bundled `style.css` adapts the surround colors to Kong.
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

(Underlying pnpm equivalents: `pnpm install`, `pnpm dev`, `pnpm build`, `pnpm export-pdf`, `pnpm export-pptx`.)

`just pptx` is fine when the recipient strictly needs a `.pptx` file (corporate distribution, audiences without browsers). For an **editable** PPTX where the recipient can change text and shapes, use the `kong-pptx-build` skill instead -- Slidev's PPTX export is one image per slide.
