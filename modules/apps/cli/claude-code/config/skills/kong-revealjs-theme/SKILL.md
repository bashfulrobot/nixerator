---
name: kong-revealjs-theme
description: Apply the Kong brand theme (kong.css + kong-footer-plugin.js + assets) to a reveal.js presentation. Use when the user asks for a Kong-branded deck, mentions "kong theme"/"kong slides"/"brand this as Kong", or builds any reveal.js presentation in a Kong context (QBRs, EBRs, customer reviews, Kong product pitches, internal Kong content). This skill ALWAYS takes priority over the generic revealjs skill's color-palette and custom-CSS guidance when the content is Kong-branded — the palette, typography, slide layouts, and footer rules are LOCKED by brand. Works from any working directory: the theme payload lives at a fixed path under ~/.claude/skills/kong-revealjs-theme/theme/ and gets copied into the project alongside the generated presentation.html.
---

# Kong Reveal.js Theme

Applies the official Kong brand theme to a reveal.js presentation. Do **not** invent colors, fonts, or layouts — everything is pre-defined in `kong.css` and the footer plugin.

## Trigger

Use this skill when:
- User explicitly asks to use the Kong theme / Kong branding / Kong slides / "our brand"
- Building a reveal.js deck whose content is clearly Kong (QBR, EBR, customer success, Kong product, internal Kong comms)
- Any presentation where the `revealjs` skill would otherwise pick its own color palette but Kong branding is required

When triggered, this skill **overrides** the following parts of the generic `revealjs` skill:
- ❌ Skip the "choose a color palette" step — the palette is fixed
- ❌ Skip the "pick web-safe fonts" step — Funnel Sans/Display are defined in `kong.css`
- ❌ Do not write an ad-hoc `styles.css` — `kong.css` is a complete stylesheet
- ✅ Still apply the layout-diversity, scannable-content, and overflow-check principles

## Workflow

### 1. Copy the theme payload into the project

The theme package lives at a fixed absolute path (installed by home-manager):

```
~/.claude/skills/kong-revealjs-theme/theme/
```

From whatever directory the user wants the presentation built in, run:

```bash
cp -r ~/.claude/skills/kong-revealjs-theme/theme/ ./kong-reveal-theme/
```

This puts `kong.css`, `kong-footer-plugin.js`, `demo.html`, `USAGE.md`, and `assets/images/` into `./kong-reveal-theme/` relative to the presentation.

### 2. Scaffold `presentation.html`

Use this boilerplate exactly — the head/body order matters (the footer plugin must load **before** `Reveal.initialize()`):

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>{{DECK TITLE}}</title>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/reveal.js/5.1.0/reveal.min.css" />
  <link rel="stylesheet" href="kong-reveal-theme/kong.css" />
  <!-- DO NOT include any reveal built-in theme (black.css, white.css, etc.) -->
</head>
<body>
  <div class="reveal">
    <div class="slides">
      <!-- slides go here -->
    </div>
  </div>

  <script src="https://cdnjs.cloudflare.com/ajax/libs/reveal.js/5.1.0/reveal.min.js"></script>
  <script src="kong-reveal-theme/kong-footer-plugin.js"></script>
  <script>
    Reveal.initialize({
      hash: true,
      center: false,          // Kong layouts use absolute positioning
      width: 1280,
      height: 720,
      margin: 0,
      transition: 'fade',
      transitionSpeed: 'fast',
      backgroundTransition: 'fade',

      kong: {
        markSrc:    'kong-reveal-theme/assets/images/kong-mark-footer.png',
        copyright:  '© Kong Inc.',
        footerCopy: 'NOT TO BE SHARED EXTERNALLY',
      },

      plugins: [ KongFooter ],
    });
  </script>
</body>
</html>
```

### 3. Pick the right slide type for each slide

The theme ships six pre-defined slide types. Use them verbatim — do not invent new layouts.

**Reference:** [`theme/USAGE.md`](theme/USAGE.md) has the complete HTML for every slide type. **Always read it before generating slides** — treat its examples as canonical.

Quick index:

| Slide Type | Section class | Use for |
|---|---|---|
| Title | `.slide-title` | First slide — product tag + big title + subtitle + date/speaker |
| Agenda | `.slide-agenda` | Section overview — numbered items in right column |
| Divider | `.slide-divider` | Between-section punctuation — bold statement on ring bg |
| Content | `.slide-content` | Most slides — section label + title + bullets/body |
| Stats | `.slide-stats` | 3×2 metrics grid (up to 6 cells; one `.highlight`) |
| Thank You | `.slide-thankyou` | Closing — contact info + large "Kong" wordmark |

### 4. Brand rules — do not violate

- **`#CCFF00` is the only accent colour.** Never introduce others. Gradients, secondary accents, alternate highlights — all banned.
- Use `<em>` inside headings to accent one key word in neon green.
- Section labels (`.section-label`) are always uppercase, small, green.
- Body text is left-aligned. Only full-screen statement slides are centred.
- Every content slide gets the Kong footer bar automatically (the plugin handles it). Slides that shouldn't have it use `data-no-footer`.
- Do not load Reveal's built-in themes alongside `kong.css` — `kong.css` is a complete replacement.
- Images go as inline `<img>` inside `<section>`, not `data-background-image` (see USAGE.md "How Backgrounds Work").

### 5. Utility classes available

From `kong.css`:

| Class | Purpose |
|---|---|
| `<em>` | Kong neon green text (only inside headings) |
| `.section-label` | Small uppercase green label above a title |
| `.kong-card` | Dark card panel (`#0D1A0E`) |
| `.kong-card-muted` | Medium dark card (`#30352F`) |
| `.kong-divider` | Thin green-tinted `<hr>` |
| `.kong-badge` | Neon green pill badge |
| `.kong-quote` | Dark left-bordered quote block |
| `.kong-step` | Numbered step row (`.kong-step-num` + `.kong-step-body`) |
| `.kong-bullets` | Square green bullet list (no default `list-style`) |
| `.kong-highlight` | Inline neon green span |
| `.kong-stats-grid` + `.kong-stat-cell` + `.kong-stat-cell.highlight` | Stats grid (see `.slide-stats`) |

If you need a visual element not in this table, check `theme/kong.css` for existing classes **before** writing inline `<style>`. Inline styles and custom CSS files are a last resort — prefer composing the theme's own classes.

### 6. Verify

After generating the HTML:

1. Open it in a browser (the `revealjs` skill's overflow checker works on Kong decks too).
2. Visually confirm: footer bar present on content slides, title slide has wordmark + product tag, no unexpected colors outside `#CCFF00` + greys.
3. For reference, `theme/demo.html` shows every slide type with real content — open it side-by-side if the output looks wrong.

## Footer Plugin Per-Slide Attributes

```html
<!-- No footer on this slide -->
<section data-no-footer>…</section>

<!-- Override right-hand text on one slide -->
<section data-footer-copy="INTERNAL ONLY">…</section>
```

## CSS Custom Properties (for adjustment within brand rules)

Defined in `theme/kong.css`:

```css
--kong-black:         #000000;
--kong-green:         #CCFF00;   /* THE only accent */
--kong-dark-green:    #0D1A0E;
--kong-border-green:  #1A3A1A;
--kong-card:          #30352F;
--kong-card-dark:     #0D1A0E;
--kong-white:         #FFFFFF;
--kong-silver:        #AAB4BB;
--kong-muted:         #8A8F89;
--kong-font-main:     'Funnel Sans', 'Helvetica Neue', sans-serif;
--kong-font-display:  'Funnel Display', 'Funnel Sans', sans-serif;
```
