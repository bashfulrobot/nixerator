# Kong typography (2026 v1.1)

Source: Kong Brand Guidelines PDF, "Typography" section. Font binaries bundled at `assets/fonts/`, all SIL Open Font License (each family carries its own `OFL.txt`).

## The three canonical typefaces

| Typeface | Role | Weights bundled |
|---|---|---|
| **Funnel Sans** | Primary — headings *and* body text. The default for essentially everything Kong writes or designs. | Light 300, Regular 400, Italic 400, Bold 700, ExtraBold 800 |
| **Roboto Mono** | Code and technical/monospace expression — config snippets, CLI output, API examples. | Light 300, Regular 400, Italic 400, Bold 700 |
| **Space Grotesk** | Buttons and CTAs *only*. Not for headings or body copy — it exists to make interactive elements feel distinct from static text. | Light 300, Regular 400, Bold 700 |

Fallback stacks (when the actual font files aren't loadable, e.g. a plain-text medium): Funnel Sans / Space Grotesk → `Helvetica Neue, Helvetica, Arial, sans-serif`; Roboto Mono → `SFMono-Regular, Menlo, monospace`.

Google Fonts CDN, if you'd rather link than bundle:
- `https://fonts.googleapis.com/css2?family=Funnel+Sans:ital,wght@0,300;0,400;0,700;0,800;1,400&display=swap`
- `https://fonts.googleapis.com/css2?family=Roboto+Mono:ital,wght@0,300;0,400;0,700;1,400&display=swap`
- `https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@300;400;700&display=swap`

## Confirmed supplementary typefaces

The public Brand Guidelines PDF only calls out the three faces above, but Kong's actual production artifacts use two more in specific supporting roles. Both are legitimate Google Fonts (verified live), and both are attested by real Kong-authored material — not an invention by any skill in this environment:

- **Funnel Display** — a display cut of the Funnel family, used for large hero/headline moments (72px+) where a slightly more expressive letterform reads better than body-duty Funnel Sans at scale. Seen in `kong-revealjs-theme`'s CSS, which was reproduced from an official "Kong template slides 2026 [dark]" deck.
- **Urbanist** — a secondary typeface used sparingly, confirmed present in the official Kong CS success-plan Google Slides template when it was inspected. That binary template is no longer vendored here (the success-plan skills were superseded by `csp-draft`), but the same Funnel Display / Urbanist supplementary faces are documented in `kong-pptx/references/kong-theme.md`.

Treat these as legitimate options for their specific roles (large display headlines; occasional secondary emphasis), not as a license to freelance — Funnel Sans/Roboto Mono/Space Grotesk remain correct for everything the guidelines PDF actually covers. If you're unsure whether a given use is "display" enough to warrant Funnel Display, default to Funnel Sans ExtraBold instead.

## Type hierarchy

The guidelines define a reference scale — use it as-is for anything resembling a marketing page, deck, or hero composition; scale proportionally for smaller contexts (UI chrome, tables, footnotes):

| Level | Typeface / weight | Size / line-height |
|---|---|---|
| Heading XL | Funnel Sans Bold | 72px / 78px |
| Heading L | Funnel Sans Bold | 32px / 38px |
| Body L | Funnel Sans Regular | 20px / 28px |
| Label | Funnel Sans Bold | 14px / 16px |
| Button | Space Grotesk | (component-driven, not a fixed size in the guidelines) |

CSS custom properties for this scale live in `assets/tokens/kong-brand.css` (`--kong-heading-xl-size`, etc.) alongside `@font-face` declarations pointing at the bundled `.ttf` files.

## Why the discipline matters

Funnel Sans doing double duty for headings *and* body is a deliberate constraint, not a gap — it keeps a page from feeling like it's stitched together from two type systems. Reach for Roboto Mono only when you're actually representing code or technical output, not as a generic "techy" accent font. Reach for Space Grotesk only on the interactive element itself (a button label), never on the surrounding copy — if you find yourself wanting Space Grotesk on a heading, that's a sign to use Funnel Sans Bold/ExtraBold instead.
