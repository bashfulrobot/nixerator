# Kong Reveal.js Theme

Official Kong brand theme for [Reveal.js](https://revealjs.com/) 4+, faithfully reproduced from the Kong Inc. PowerPoint template.

---

## Files

```
kong-reveal-theme/
├── kong.css                  ← Complete theme stylesheet (include this)
├── kong-footer-plugin.js     ← Reveal.js 4+ plugin — auto-injects Kong footer
├── demo.html                 ← Working demo of every slide type
├── USAGE.md                  ← This file
└── assets/
    └── images/
        ├── kong-mark.png           Kong logo mark (neon green, transparent bg)
        ├── kong-wordmark.png       Kong full wordmark (mark + "Kong" text)
        ├── kong-mark-footer.png    Small mark used in the footer bar
        ├── bg-rays-faded.png       Hero title background — fades baked into alpha
        ├── bg-hero-ring.png        Section-divider background (dark ring)
        ├── bg-torus.png            Agenda slide background (torus)
        ├── bg-loop.png             Abstract loop (decorative)
        ├── glow-green.png          Soft green glow (decorative overlay)
        ├── connectivity-lines.png  Dashed connectivity lines graphic
        └── bg-network.png          Network/API diagram decorative
```

---

## Quick Start

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>My Kong Deck</title>

  <!-- 1. Reveal.js core CSS (required) -->
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/reveal.js/5.1.0/reveal.min.css" />

  <!-- 2. Kong theme — do NOT also include a reveal built-in theme (black.css etc.) -->
  <link rel="stylesheet" href="path/to/kong-reveal-theme/kong.css" />
</head>
<body>
  <div class="reveal">
    <div class="slides">

      <!-- your slides here -->

    </div>
  </div>

  <!-- 3. Reveal.js core -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/reveal.js/5.1.0/reveal.min.js"></script>

  <!-- 4. Kong footer plugin — load BEFORE Reveal.initialize() -->
  <script src="path/to/kong-reveal-theme/kong-footer-plugin.js"></script>

  <script>
    Reveal.initialize({
      hash: true,
      center: false,       // Kong layouts use absolute positioning
      width: 1280,
      height: 720,
      margin: 0,
      transition: 'fade',
      transitionSpeed: 'fast',
      backgroundTransition: 'fade',

      // Kong footer plugin config (all optional)
      kong: {
        markSrc:    'path/to/kong-reveal-theme/assets/images/kong-mark-footer.png',
        copyright:  '© Kong Inc.',
        footerCopy: 'NOT TO BE SHARED EXTERNALLY',
      },

      plugins: [ KongFooter ],
    });
  </script>
</body>
</html>
```

> **Important:** Do **not** add a second `<link>` to any of Reveal's built-in themes (`black.css`, `white.css`, etc.). `kong.css` is a complete replacement.

---

## How Backgrounds Work

Reveal.js `data-background-image` renders in a **full-viewport layer** behind all slides — it is not clipped to the slide boundary, which causes the image to bleed outside the slide frame.

Instead, the Kong theme places background images as **regular `<img>` elements inside the `<section>`**, absolutely positioned. This keeps them strictly within the slide boundary.

The title slide background (`bg-rays-faded.png`) has gradient fades **baked into its alpha channel** (left, top, and bottom edges dissolve into black; right edge stays crisp). No CSS masking is needed — it just works.

For solid-colour backgrounds and the section divider full-bleed effect, `data-background-color` and `data-background-image` are still used where the full-viewport bleed is acceptable (e.g. the divider slide intentionally fills edge-to-edge).

---

## How the Footer Plugin Works

`KongFooter` is a standard **Reveal.js 4+ plugin** (an object with `id` + `init`). On the `ready` event it iterates all slides and appends the `.kong-footer` bar to any slide that does **not** have `data-no-footer`.

Slides that need a custom footer (title, closing) use `data-no-footer` to skip auto-injection and include their own `.kong-footer` div in the markup directly.

---

## Slide Types Reference

### 1. Title Slide

```html
<section class="slide-title" data-no-footer data-background-color="#000000">

  <!-- Background as inline img — stays inside the slide boundary.
       Fades are baked into the PNG alpha; no CSS masking needed. -->
  <img class="slide-title-bg" src="assets/images/bg-rays-faded.png" alt="" aria-hidden="true" />

  <img class="title-logo" src="assets/images/kong-wordmark.png" alt="Kong" />

  <div class="title-content">
    <p class="product-tag">Kong Konnect</p>
    <h1>Presentation<br>Title</h1>
    <p class="subtitle">The Unified API and AI Platform</p>
  </div>

  <div class="meta-bar">
    <span class="meta-date">JAN 2026</span>
    <span class="meta-speaker">Speaker Name</span>
  </div>

  <!-- Manual footer because data-no-footer skips the plugin -->
  <div class="kong-footer">
    <img class="footer-mark" src="assets/images/kong-mark-footer.png" alt="Kong" />
    <span class="footer-label">AI<br>CONNECTIVITY</span>
    <span class="footer-copy">© Kong Inc.</span>
    <span class="footer-right">NOT TO BE SHARED EXTERNALLY</span>
  </div>
</section>
```

---

### 2. Agenda Slide

```html
<section class="slide-agenda" data-background-color="#000000">
  <div class="agenda-left">
    <span class="section-label">Agenda</span>
    <h2>January '26</h2>
  </div>
  <div class="agenda-right">
    <div class="agenda-item">
      <span class="agenda-num">1</span>
      <span class="agenda-title">Section One</span>
    </div>
    <!-- repeat for each item -->
  </div>
</section>
```

---

### 3. Section Divider

```html
<section class="slide-divider" data-no-footer
  data-background-image="assets/images/bg-hero-ring.png"
  data-background-size="cover"
  data-background-color="#000000">
  <div class="divider-content">
    <h2>A bold statement with one <em>green word.</em></h2>
  </div>
</section>
```

---

### 4. Standard Content

```html
<section class="slide-content" data-background-color="#000000">
  <div class="slide-header">
    <span class="section-label">Section Name</span>
    <h2>Slide title with <em>green accent</em></h2>
  </div>
  <ul class="kong-bullets">
    <li>First point with supporting detail.</li>
    <li>Second point with supporting detail.</li>
  </ul>
</section>
```

---

### 5. Stats / Metrics Grid

```html
<section class="slide-stats" data-background-color="#000000">
  <div class="slide-header">
    <h2>Our <em>numbers</em> speak for themselves</h2>
  </div>
  <div class="kong-stats-grid">
    <div class="kong-stat-cell">
      <span class="kong-stat-value">100K</span>
      <p class="kong-stat-desc">Description of this metric.</p>
    </div>
    <div class="kong-stat-cell highlight">
      <!-- add class="highlight" to the featured cell -->
      <span class="kong-stat-value">99.99%</span>
      <p class="kong-stat-desc">Uptime guarantee.</p>
    </div>
    <!-- up to 6 cells in a 3×2 grid -->
  </div>
</section>
```

---

### 6. Thank You / Closing

```html
<section class="slide-thankyou" data-no-footer data-background-color="#000000">
  <div class="ty-top">
    <h2 class="ty-headline">Thank you!</h2>
    <div class="ty-cta">
      <h3>Ready for what's next?</h3>
      <p class="subtitle">Let's talk</p>
    </div>
    <div class="ty-contact">
      <p>Kong Inc.<br>
        <a href="mailto:contact@konghq.com">contact@konghq.com</a><br>
        Konghq.com</p>
    </div>
  </div>
  <div class="ty-wordmark">
    <span class="ty-wordmark-text">Kong</span>
  </div>
  <div class="kong-footer"><!-- manual footer --></div>
</section>
```

---

## Utility Classes

| Class | Purpose |
|---|---|
| `<em>` | Kong neon green text (use inside headings for accent words) |
| `.section-label` | Small uppercase green label above a title |
| `.kong-card` | Dark card panel (`#0D1A0E`) |
| `.kong-card-muted` | Medium dark card (`#30352F`) |
| `.kong-divider` | Thin green-tinted `<hr>` |
| `.kong-badge` | Neon green pill badge |
| `.kong-quote` | Dark left-bordered quote block |
| `.kong-step` | Numbered step row (`.kong-step-num` + `.kong-step-body`) |
| `.kong-bullets` | Square green bullet list (no default `list-style`) |
| `.kong-highlight` | Inline neon green span |

---

## CSS Custom Properties

```css
:root {
  --kong-black:         #000000;
  --kong-green:         #CCFF00;   /* Only accent — never swap for another colour */
  --kong-dark-green:    #0D1A0E;
  --kong-border-green:  #1A3A1A;
  --kong-card:          #30352F;
  --kong-card-dark:     #0D1A0E;
  --kong-white:         #FFFFFF;
  --kong-silver:        #AAB4BB;
  --kong-muted:         #8A8F89;
  --kong-font-main:     'Funnel Sans', 'Helvetica Neue', sans-serif;
  --kong-font-display:  'Funnel Display', 'Funnel Sans', sans-serif;
}
```

---

## Footer Plugin Options

```js
Reveal.initialize({
  kong: {
    footerCopy: 'CONFIDENTIAL – DO NOT DISTRIBUTE',  // right-hand text
    copyright:  '© Kong Inc. 2026',                  // centre-left text
    markSrc:    'path/to/kong-mark-footer.png',       // logo path
  },
  plugins: [ KongFooter ],
});
```

**Per-slide attributes:**

```html
<!-- No footer on this slide -->
<section data-no-footer>…</section>

<!-- Override right-hand text on one slide -->
<section data-footer-copy="INTERNAL ONLY">…</section>
```

---

## Brand Rules

- `#CCFF00` is the **only** accent colour. Never introduce others.
- Use `<em>` to highlight a key word in neon green within titles.
- Section labels: always uppercase, always green, always small.
- Left-align all body text; only full-screen statement slides are centred.
- Every content slide must show the Kong footer bar.
- Do not load Reveal's built-in theme CSS alongside `kong.css`.
