---
name: kong-branding
description: "Kong Inc.'s official 2026 v1.1 brand system — the canonical source for Kong colors, fonts, logos, and trademark/usage rules. Use this whenever producing or reviewing ANY Kong-branded material that isn't a .pptx deck or reveal.js presentation: web pages, HTML/CSS, images, social graphics, email signatures, one-pagers, badges, PDFs, documents, or general brand questions ('what's Kong's accent color', 'what font does Kong use', 'is this on-brand for Kong', 'does this violate Kong's trademark guidelines'). Also use it to AUDIT existing material — a partner's asset, an old deck, a webpage — for brand/trademark compliance; it bundles a mechanical color+font scanner plus the full permitted/prohibited usage rules. Trigger eagerly on 'Kong brand', 'Kong colors', 'Kong logo', 'Kong branding', 'on-brand for Kong', 'brand guidelines', 'brand compliance', or 'compatible with Kong' phrasing questions, even if the user doesn't name this skill directly. For .pptx decks use kong-pptx; for reveal.js presentations use kong-revealjs-theme — this skill is still the right place to check what those skills' brand values SHOULD be if they look wrong."
---

# Kong Branding

Kong Inc.'s official 2026 v1.1 brand guidelines, extracted from `konghq.com/company/branding`, the Brand Guidelines PDF, and the Press Kit. This is the **source of truth** — if another Kong-branded skill in this environment disagrees with a value here, this skill wins (see [references/drift-and-consolidation.md](references/drift-and-consolidation.md) for the known mismatches and why).

## Quick reference

The four things people ask for most, so a trivial question doesn't need a file read:

| | |
|---|---|
| **Accent color** | Electric lime `#CCFF00` — the *only* accent. One accented word/element per composition, never a gradient, never a second accent. |
| **Dark base** | Dark green `#000F06` |
| **Neutrals / White** | Bay `#B7BDB5`, White `#FFFFFF`, plus a 10-step ramp `#E7EDE5`→`#101110` |
| **Type** | **Funnel Sans** (headings + body, the default for everything) · **Roboto Mono** (code) · **Space Grotesk** (buttons/CTAs only) |

Full detail: [references/colors.md](references/colors.md), [references/typography.md](references/typography.md).

## Routing — decks go elsewhere

This skill does **not** own `.pptx` or reveal.js output — those have dedicated skills with their own templates and render pipelines:

- Building or editing a `.pptx` deck → use `kong-pptx`
- Building a reveal.js presentation → use `kong-revealjs-theme`
- A Kong CS success-plan deck → use `kong-success-plan-pptx`

Come back to *this* skill from within those if their bundled brand values look wrong or you need to check what the official value should be — that's exactly what [references/drift-and-consolidation.md](references/drift-and-consolidation.md) is for.

Everything else Kong-branded — web pages, HTML/CSS/SVG, images, social graphics, email signatures, one-pagers, PDFs authored outside the deck pipelines, or a plain brand question — belongs here.

## Applying the brand

1. **Pick a theme.** Dark or Electric are priority usage — default to Dark unless the context calls for Bay (editorial/print) or White (light-mode host, print, documents). See [references/colors.md](references/colors.md#themes).
2. **Pull the machine-readable tokens** rather than retyping hex codes or font names by hand:
   - `assets/tokens/kong-brand.css` — `:root` custom properties + `@font-face` declarations pointing at the bundled fonts. Drop this into an HTML/CSS project directly.
   - `assets/tokens/kong-brand.json` — the same data as structured tokens, for anything that isn't CSS (a design tool, a codegen step, a non-web target).
3. **Pull the logo.** `assets/logos/for-light-backgrounds/` or `assets/logos/for-dark-backgrounds/` — pick by the actual background color behind the logo, not your overall theme. SVG for anything digital, PNG as a fallback, EPS/AI for print handoff. Full variant guide: [references/logo-usage.md](references/logo-usage.md).
4. **Respect the constraints that make it read as Kong, not "dark background with a green accent":**
   - One accent, used once (or once per major section) — not on every heading.
   - Funnel Sans everywhere except code (Roboto Mono) and buttons (Space Grotesk).
   - Never edit, distort, recolor, or reconfigure the logo.
   - Clear space around the logo = 1× the logomark's own key unit.
5. Fonts are bundled at `assets/fonts/<family>/*.ttf` (SIL OFL — each family carries its own `OFL.txt`), or link the Google Fonts CDN URLs in [references/typography.md](references/typography.md) if you'd rather not vendor the files.

## Auditing existing material for brand compliance

Two passes — mechanical, then judgment. Don't stop at the mechanical pass; it can't see logo distortion or missing disclaimers.

1. **Mechanical scan** — flags off-palette hex codes and off-brand `font-family` declarations:
   ```bash
   python3 scripts/brand-audit.py <file-or-directory>
   ```
   Exits 0 clean, 1 if it found something. Cross-check any flagged value against [references/colors.md](references/colors.md) and [references/drift-and-consolidation.md](references/drift-and-consolidation.md) before calling it a violation — an older Kong skill's output may use a pre-2026-refresh value that was correct under a prior internal convention, not actually wrong.

2. **Judgment checklist** — things a script can't see, from [references/trademark-usage.md](references/trademark-usage.md) and [references/logo-usage.md](references/logo-usage.md):
   - Is the logo edited, recolored, distorted, or merged into another logo?
   - If this is third-party/external material: does it use "Kong" in a product, company, or domain name? Does it imply Kong sponsorship or endorsement? Is the reviewer's own brand more prominent than Kong's?
   - If it's educational material: does it carry the required disclaimer — *"(Title) is not affiliated with or otherwise sponsored by Kong, Inc."*?
   - Is electric lime used as the single accent, or has it crept into a gradient / second-accent role?

Only reach for the trademark rules ([references/trademark-usage.md](references/trademark-usage.md)) when the material is genuinely third-party or external-facing — most internal Kong material doesn't trigger them at all. That file explains the distinction.

## Reference map

| File | Read it for |
|---|---|
| [references/colors.md](references/colors.md) | Full palette (hex/RGB/CMYK/Pantone), neutral ramp, themes, the "single accent" rule explained |
| [references/typography.md](references/typography.md) | The three typefaces, weights, type hierarchy/scale, Google Fonts CDN links |
| [references/logo-usage.md](references/logo-usage.md) | Logomark vs. logotype, bundled file map, themes, clear space, do/don't |
| [references/trademark-usage.md](references/trademark-usage.md) | Verbatim permitted/prohibited/required usage rules + the disclaimer string |
| [references/graphic-style.md](references/graphic-style.md) | Design principles, blueprint guides, connectivity-layer diagrams — optional polish, not a checklist |
| [references/drift-and-consolidation.md](references/drift-and-consolidation.md) | Where other Kong skills in this environment disagree with this one, and why |

Questions outside these guidelines — an intended use they don't cover — go to **design@konghq.com**, not a guess.
