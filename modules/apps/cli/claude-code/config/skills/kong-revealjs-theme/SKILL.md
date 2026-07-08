---
name: kong-revealjs-theme
description: Build a Kong-branded reveal.js presentation. Use when the user asks for a Kong-branded deck, mentions "kong theme"/"kong slides"/"brand this as Kong", or builds any reveal.js presentation in a Kong context (QBRs, EBRs, customer reviews, Kong product pitches, internal Kong content). This skill ALWAYS takes priority over the generic revealjs skill when the content is Kong-branded: the palette, typography, layouts, and footer are LOCKED by brand. The deck is authored as data in a deck.js file and rendered by a bundled engine, so you write content, not markup or CSS. Works from any working directory: the theme payload lives at ~/.claude/skills/kong-revealjs-theme/theme/ and gets copied into the project. reveal.js is vendored, so decks need no build step and no network.
---

# Kong Reveal.js Theme

Builds a Kong-branded reveal.js deck. You write content as data in `deck.js`; a bundled
render engine turns it into the slides. Do **not** invent colours, fonts, or layouts, and
do **not** edit the theme files. Everything about the look is fixed in `kong.css` and the
render engine.

This is the **clone-not-mimic** model. The theme owns the brand and renders eighteen fixed
layouts. You supply only the content, so every Kong deck comes out identical in style.

## Trigger

Use this skill when:
- The user asks for a Kong-branded deck / Kong slides / "our brand" on a presentation.
- The content is clearly Kong (QBR, EBR, customer success, Kong product, internal comms).
- Any reveal.js deck where the generic `revealjs` skill would otherwise pick a palette but
  Kong branding is required.

When triggered, this skill **overrides** the generic `revealjs` skill: skip choosing a
palette, skip picking fonts, skip writing custom CSS. All of that is locked here.

## Workflow

### 1. Copy the theme payload into the project

The payload lives at a fixed path:

```bash
cp -r ~/.claude/skills/kong-revealjs-theme/theme/ ./kong-deck/
```

This puts `presentation.html`, `theme.js`, `kong.css`, `kong-footer-plugin.js`, `vendor/`
(reveal.js, offline), `assets/`, `deck.example.js`, `README.md`, and `CATALOG.md` into
`./kong-deck/`.

### 2. Author `deck.js`

**Read [`theme/CATALOG.md`](theme/CATALOG.md) before writing slides.** It lists every layout,
its fields, and a copy-paste example. Then write `./kong-deck/deck.js`:

```js
window.DECK = {
  title: "Platform Review",
  slides: [
    { layout: "title", eyebrow: "*Kong* Konnect", title: "Platform Review",
      subtitle: "The Unified API and AI Platform", date: "JAN 2026", speaker: "Speaker Name" },
    { layout: "agenda", heading: "January '26", items: ["Where we are", "What changed", "What's next"] },
    { layout: "thank-you", title: "Thank you!", tagline: "Ready for what's next?",
      contact: ["Kong Inc.", "contact@konghq.com", "konghq.com"] }
  ]
};
```

Each slide is `{ layout, ...fields }`. Two text conventions: wrap one word in `*asterisks*`
to accent it neon green, and use `\n` in a heading for a line break.

The contract: **you write `deck.js` and nothing else.** Never edit `theme.js`, `kong.css`,
or any other payload file. That is what keeps the deck on brand. Starting from a copy of
`deck.example.js` (a worked deck using every layout) is the fastest path.

### 3. View

Open `./kong-deck/presentation.html` in a browser. No build step, no Node, no network.
reveal.js scales each slide to fit any screen. To share a fixed copy, print to PDF from the
browser.

## Layouts

Eighteen named layouts cover the whole official template. Choose by intent; full fields and
examples are in [`theme/CATALOG.md`](theme/CATALOG.md).

`title`, `agenda`, `divider`, `section-statement`, `content`, `big-stat`, `stats-grid`,
`value-cards`, `team`, `timeline`, `partnerships`, `green-inverted`, `thank-you`,
`awards-grid`, `mixed-stats`, `persona`, `charts`, `architecture`, plus `freeform-panel`.

Data-heavy layouts (`stats-grid`, `persona`, `charts`, `architecture`, and so on) keep a
fixed composition and take the specific data as fields. Replace the values; the structure
does not change.

## Images

Any layout takes an optional transparent image that auto-hides when omitted:

```js
{ layout: "content", title: "...", bullets: ["..."],
  image: { src: "assets/robot.png", anchor: "bottom-right", size: "520px" } }
```

`anchor` is one of `right`, `bottom-right`, `bottom-left`, `left`, `center-right`. A px
`size` sets height; a `%` size sets width. To generate transparent subjects, use the
`image-prompts` skill.

## Brand rules (do not violate)

- `#CCFF00` is the only accent colour. No gradients, no second accent. One accented word per
  heading via `*asterisks*`.
- Type is Funnel Sans (body/headings) / Funnel Display (large hero moments) / Roboto Mono
  (code) / Space Grotesk (CTA pills like `kong-pt-pill` only), loaded by the theme. Full
  brand documentation, tokens, and logos live in the `kong-branding` skill.
- The footer bar and corner frame appear on every slide. Per-slide `noFooter: true` removes
  the footer; `footerNotice` overrides the right-hand notice.
- Body text is left-aligned; only full-screen statement slides are centred.
- Do not load any reveal built-in theme alongside `kong.css`.

## Escape hatch

For a one-off slide no named layout covers, use the `freeform-panel` layout. It gives a
branded empty canvas (frame + footer) and takes raw `html` that composes with the `kong-*`
utility classes in `kong.css`. Reach for this instead of editing the theme.

## Footer text

Override per deck in `deck.js`:

```js
footer: { label: "AI CONNECTIVITY", copyright: "© Kong Inc.", notice: "NOT TO BE SHARED EXTERNALLY" }
```

## Updating reveal.js

reveal.js is vendored and pinned (no build, no network). It does not need periodic updates.
To bump it, follow `theme/vendor/VERSION.txt`.
