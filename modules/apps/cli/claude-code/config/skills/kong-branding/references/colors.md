# Kong color palette (2026 v1.1)

Source: Kong Brand Guidelines PDF, "Colors" section. Machine-readable copy: `assets/tokens/kong-brand.json` / `assets/tokens/kong-brand.css`.

## Brand colors

| Name | Hex | RGB | CMYK | Pantone | Role |
|---|---|---|---|---|---|
| Dark green | `#000F06` | 0, 15, 6 | 75, 60, 70, 85 | Black 3 U | Primary dark surface / canvas |
| Electric lime | `#CCFF00` | 204, 255, 0 | 25, 0, 100, 0 | 2297 U | **The** accent |
| Bay | `#B7BDB5` | 183, 189, 181 | 30, 20, 27, 0 | 7527 U | Warm neutral (== neutral 300) |
| White | `#FFFFFF` | 255, 255, 255 | 0, 0, 0, 0 | White U | Surface / reversed text |

**Electric lime is the only accent color.** Kong's system deliberately uses one loud color against dark green, not a palette of competing accents. When you build something Kong-branded, that constraint is doing real work: it's what makes the brand read as confident rather than busy. Concretely:
- One accented word, phrase, or element per composition — not every heading, not every button.
- No gradients built from the accent. No second "accent-adjacent" color invented to fill a gap — reach for the neutral ramp instead.
- Electric lime on electric lime, or lime text on a light background, breaks contrast — pair it with dark green or the darker neutrals (700–900).

## Neutral ramp

| Step | Hex |
|---|---|
| 50 | `#E7EDE5` |
| 100 | `#D7DED4` |
| 200 | `#CDD4CB` |
| 300 | `#B7BDB5` (Bay) |
| 400 | `#A1A69F` |
| 500 | `#858983` |
| 600 | `#676B66` |
| 700 | `#4A4D49` |
| 800 | `#2D2E2C` |
| 900 | `#101110` |

Use the ramp for body text, borders, muted UI, and secondary surfaces — anything that isn't the one accent moment.

## Themes

The brand guidelines define four surface themes, used for logo lockups and full compositions alike:

- **Dark theme** (priority) — dark green canvas, white/lime foreground.
- **Electric theme** (priority) — lime canvas, dark green foreground. Use sparingly; a full lime background is a strong, attention-grabbing choice reserved for hero moments, not everyday content.
- **Bay theme** — bay/neutral canvas, dark foreground. A softer, editorial alternative to dark theme.
- **White theme** — white canvas, dark foreground. Standard for print, documents, and anywhere dark theme would fight the surrounding UI (e.g. embedding in a light-mode host page).

Dark and Electric are marked priority usage in the guidelines — default to one of these two unless the context (print, a light-mode host surface, document backgrounds) calls for Bay or White.

## A note on a naming inconsistency you may find elsewhere

The full-color primary logo lockup in the press kit renders the dark mark as `#001408`; the transparent/single-color logo files use `#000F06`. These are visually indistinguishable and both trace back to Kong's dark green — **`#000F06` is the canonical value** (it's what the guidelines PDF states explicitly on the Colors page). If you're auditing older Kong material and see `#001408`, treat it as the same color, not a violation.

Several existing Kong-branded skills in this environment (`kong-revealjs-theme`, `kong-pptx`, `kong-doc-build`) currently use other dark-green values (`#07120A`, `#0D1A0E`, `#001408`) that predate this 2026 refresh or drifted from it — see `drift-and-consolidation.md`. Don't treat those as authoritative; this file and the token files are.
