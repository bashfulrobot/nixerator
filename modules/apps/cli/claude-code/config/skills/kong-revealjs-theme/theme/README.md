# Kong Reveal.js Theme

A reusable, brand-locked reveal.js theme that reproduces Kong's official 2026 dark
template. You build a deck by writing data, not markup: list your slides in
`deck.js`, open `presentation.html`, done. No build step, no Node, no install. The
only dependency is a web browser.

The theme owns the brand (colours, type, the footer bar, the corner frame, the
background art) and renders eighteen fixed layouts. You supply content; the look
stays identical from one deck to the next.

---

## Use it

1. Copy `deck.example.js` to `deck.js`.
2. Edit `deck.js`: change the slide content.
3. Open `presentation.html` in a browser.

That is the whole loop. reveal.js scales each slide to fit the window, so the same
file looks right on a laptop, a projector, or a phone. To share a fixed copy, print
to PDF from the browser (reveal has a built-in print mode).

A new deck is a copy of the folder with its own `deck.js`.

---

## deck.js

`deck.js` sets one global, `window.DECK`:

```js
window.DECK = {
  title: "Platform Review",            // browser tab title
  footer: {                            // optional; these are the defaults
    label: "AI CONNECTIVITY",
    copyright: "© Kong Inc.",
    notice: "NOT TO BE SHARED EXTERNALLY"
  },
  slides: [
    { layout: "title", eyebrow: "*Kong* Konnect", title: "Platform Review",
      subtitle: "The Unified API and AI Platform", date: "JAN 2026", speaker: "Speaker Name" },
    { layout: "agenda", heading: "January '26", items: ["Where we are", "What changed", "What's next"] },
    { layout: "thank-you", title: "Thank you!", tagline: "Ready for what's next?",
      contact: ["Kong Inc.", "contact@konghq.com", "konghq.com"] }
  ]
};
```

Each slide is an object with a `layout` and that layout's fields. Two conventions
apply anywhere text is shown:

- Wrap one word in `*asterisks*` to accent it neon green: `"Fragmentation drives *AI failure*"`.
- Use `\n` in a heading to force a line break.

Deck-level options (all optional): `footer` (text overrides), `slideNumber: false`
to hide page numbers, `controls: true` / `progress: true` to show reveal's on-screen
nav, `notes: false` to drop the speaker-notes plugin, `transition` (default `fade`).

Per-slide options on any layout: `image` (an optional transparent image, see below),
`noFooter: true` to hide the footer on that slide, `footerNotice` to override the
right-hand notice on that slide.

---

## Layouts

Eighteen named layouts cover all 30 slides of the source deck. Full field lists and a
copy-paste example for each are in `CATALOG.md`. Quick index:

| Layout | For | `variant` |
|--------|-----|-----------|
| `title` | Opening slide | `cobrand` adds a co-brand logo + speaker photo |
| `agenda` | Section overview |  |
| `divider` | Punctuation between sections |  |
| `section-statement` | A claim with supporting body |  |
| `content` | Title + bullets or body |  |
| `big-stat` | Bullets anchored by one huge number |  |
| `stats-grid` | Up to 6 metric cells |  |
| `value-cards` | Numbered value/benefit cards | `2` or `3` |
| `team` | Headshot grid | `grid` or `title-left` |
| `timeline` | Sequenced steps | `line` or `cards` |
| `partnerships` | Partner cards | `2` or `4` |
| `green-inverted` | High-impact statement on neon background |  |
| `thank-you` | Closing slide with big wordmark |  |
| `awards-grid` | Awards / market-share / rank / quote mix |  |
| `mixed-stats` | Headline + mixed stat cards (one filled green) |  |
| `persona` | Customer-segment dashboard |  |
| `charts` | Bubble + bar comparison |  |
| `architecture` | Node-and-flow diagram |  |
| `freeform-panel` | A branded empty canvas for a true one-off (takes raw `html`) |  |

The data-heavy layouts (`stats-grid`, `persona`, `charts`, `architecture`, and the
rest) keep a fixed composition and expose the specific data as fields. You replace the
values; the structure does not change.

---

## Images

Any layout can carry an optional transparent image (a product shot, a die-cut
illustration, a mascot). It auto-hides when you leave it out.

```js
{ layout: "content", title: "What reusable tooling buys you",
  bullets: ["Deterministic", "Auditable", "Reusable"],
  image: { src: "assets/robot.png", anchor: "bottom-right", size: "520px" } }
```

| Field | Meaning | Default |
|-------|---------|---------|
| `src` | Path to a PNG/SVG/WebP with transparency | required |
| `anchor` | `right`, `bottom-right`, `bottom-left`, `left`, `center-right` | `bottom-right` |
| `size` | A px value sizes height (`"520px"`); a % value sizes width (`"46%"`) | `480px` |
| `layer` | `front` sits over the panel; `back` sits behind text as a faint backdrop | `front` |
| `alt` | Accessibility text | `""` |

When an image is present, the layout narrows its text column so the words clear the
image. You only name an anchor and a size.

To generate transparent subjects to drop in, the `image-prompts` skill produces clean
die-cut images on a transparent background.

---

## What's locked

These are brand rules; the theme enforces them.

- `#CCFF00` is the only accent colour. One word per heading may be accented with it.
- Type is Funnel Sans (body/headings) / Funnel Display (hero moments) / Roboto Mono (code) /
  Space Grotesk (CTA pills only). See the `kong-branding` skill for the full brand system.
- The footer bar and corner frame appear on every slide.
- Body text is left-aligned; only full-screen statement slides are centred.

You can change footer text per deck, add a `cobrand` logo, and add optional images.
Everything else is fixed.

---

## Files

```
presentation.html      fixed shell; never edit
theme.js               render engine + all layouts; never edit
kong.css               brand stylesheet; never edit
kong-footer-plugin.js  the footer bar
vendor/                reveal.js, pinned and offline (see vendor/VERSION.txt)
assets/                Kong background art, marks, wordmark
deck.js                YOUR content (copy of deck.example.js)
deck.example.js        a worked deck using every layout
CATALOG.md             every layout: fields + a copy-paste example
```

---

## For an AI building a deck

The contract is simple: **write `deck.js` and nothing else.** Do not edit `theme.js`,
`kong.css`, or any other file. That is what keeps every generated deck on brand.

1. Read `CATALOG.md`. Pick the layout whose purpose matches each slide's intent.
2. Fill that layout's fields with real content. Leave optional fields out.
3. For data slides, replace the data, not the structure.
4. Add an `image` only when asked, and keep it optional.
5. Use `freeform-panel` only for a one-off no named layout covers.
6. Open `presentation.html` to check the result.

If a slide does not fit any layout, reach for `freeform-panel` rather than editing the
theme.
