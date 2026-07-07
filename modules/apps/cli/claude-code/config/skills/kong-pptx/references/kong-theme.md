# Kong theme reference (pptxgenjs)

Full Kong brand documentation — colors, typography, logo files, trademark rules — lives in the
`kong-branding` skill; treat it as the base source of truth. This file is the pptx-specific
*application* of that brand: the exact hex/font values to use in `pptxgenjs` calls, the footer
bar helper, and the layout patterns `SKILL.md` refers to.

## Core palette

**Dark theme (default):**

| Role | Hex |
|---|---|
| Background | `000000` (near-black) |
| Primary text | `FFFFFF` (white) |
| Accent | `CCFF00` (the only accent — see [Accent Color Usage](#accent-color-usage)) |
| Secondary text | `AAB4BB` (silver) |
| Muted text | `8A8F89` |
| Card fills | `30352F` |

**Light theme:**

| Role | Hex |
|---|---|
| Background | `D7DED4` (warm gray-green) |
| Primary text | `42453E` (dark charcoal-green) |
| Accent | `CCFF00` (the only accent) |
| Secondary text | `737772` |
| Muted text | `666666` |
| Card fills | `42453E` |

Kong's official Brand Guidelines PDF specifies dark green as a flat `000F06`. This deck theme's near-black `000000` background is intentionally darker/higher-contrast for on-screen/projector legibility — treat it as the established, working choice for pptx output rather than "correcting" it to `000F06`. If you're building brand material *outside* a deck (a web page, a document), use `kong-branding`'s documented `000F06` instead — this pptx-specific override doesn't apply there.

## Fonts

| Typeface | Role |
|---|---|
| **Funnel Sans** | Primary — SemiBold for titles, Medium for subheadings, Regular for body, Light for captions. |
| **Funnel Display** | Hero titles on title slides only — a display cut of Funnel for large-scale headline moments. |
| **Roboto Mono** | Any code/config snippet or technical/monospace content on a slide. |
| **Space Grotesk** | Buttons and CTA labels only — not headings, not body copy. |
| **Urbanist** | Secondary, used sparingly for select label/emphasis contexts. |

All five are legitimate Google Fonts confirmed in Kong's own production templates (see `kong-branding/references/typography.md` and `references/drift-and-consolidation.md` for the evidence trail). Funnel Sans still does the vast majority of the work — reach for the others only in the specific roles above, not as general variety.

`fontFace` in pptxgenjs takes the family name directly, e.g. `fontFace: "Funnel Sans"`. If a render environment lacks these fonts installed, pptxgenjs/LibreOffice will substitute a system font — install the family locally (see `kong-branding/assets/fonts/`) for accurate rendering, or accept the substitution for a quick draft.

## Typography scale

| Element | Size | Weight |
|---------|------|--------|
| Hero title | 60-72pt | Bold |
| Slide title | 36pt | Bold |
| Section label | 9-10pt | Bold, uppercase, accent color |
| Subtitle | 22-24pt | Bold |
| Body | 14-16pt | Regular |
| Stats | 48-72pt | Bold, accent color |
| Footer | 7-8pt | Light |

## Logo assets

`kong-pptx` doesn't bundle its own logo images — use the wordmark/mark PNGs already vendored in `kong-revealjs-theme/theme/assets/images/` (`kong-wordmark.png`, `kong-mark.png`, `kong-mark-footer.png`), which are pre-sized raster exports proven to work in decks. If you need a size or format those don't cover, the vector originals are in `kong-branding/assets/logos/` (SVG/PNG/EPS/AI, light and dark background variants) — render from there instead of asking the user for a logo file.

## Footer bar

Every content slide gets a Kong footer bar at `y = 5.27"` (10×5.625" LAYOUT_16x9): Kong logo mark, "AI CONNECTIVITY" in green, "© Kong Inc.", a confidentiality notice, and the slide number.

```javascript
const C = {
  black: "000000", white: "FFFFFF", green: "CCFF00",
  silver: "AAB4BB", muted: "8A8F89", card: "30352F",
};
const FONT = "Funnel Sans";
const IMG = path.join(__dirname, "assets", "images"); // kong-mark-footer.png lives here

function addKongFooter(slide, pageNum, notice = "NOT TO BE SHARED EXTERNALLY") {
  slide.addShape(pres.shapes.LINE, {
    x: 0.4, y: 5.2, w: 9.2, h: 0, line: { color: C.card, width: 1 },
  });
  slide.addImage({ path: path.join(IMG, "kong-mark-footer.png"), x: 0.4, y: 5.3, w: 0.22, h: 0.22 });
  slide.addText("AI CONNECTIVITY", {
    x: 0.68, y: 5.3, w: 2.2, h: 0.22, fontFace: FONT, fontSize: 7,
    color: C.green, bold: true, charSpacing: 1, valign: "middle", margin: 0,
  });
  slide.addText("© Kong Inc.", {
    x: 3.0, y: 5.3, w: 2.0, h: 0.22, fontFace: FONT, fontSize: 7,
    color: C.muted, valign: "middle", margin: 0,
  });
  slide.addText(notice, {
    x: 5.2, y: 5.3, w: 3.5, h: 0.22, fontFace: FONT, fontSize: 7,
    color: C.muted, valign: "middle", align: "right", margin: 0,
  });
  slide.addText(String(pageNum), {
    x: 9.15, y: 5.3, w: 0.45, h: 0.22, fontFace: FONT, fontSize: 7,
    color: C.muted, align: "right", valign: "middle", margin: 0,
  });
}
```

Call `addKongFooter(slide, n)` on every content slide (title slides typically skip it). Override `notice` per-deck if the sensitivity level differs from the default (e.g. `"INTERNAL DRAFT · NOT FOR EXTERNAL USE"` for a working draft) — see how `renewal-projection` does this.

## Slide types

- Title slide (hero text, Kong logo, subtitle, date, speaker)
- Section divider (bold statement, one word highlighted in green)
- Stats/metrics grid (large green numbers, muted descriptions)
- Content slides (section label + title + body)
- Numbered steps / values (1, 2, 3 in green with descriptions)
- Timeline (horizontal milestones)
- Closing / Thank You (contact info, Kong wordmark background)

## Accent color usage

`CCFF00` is the ONLY accent color. Use it for: key words in titles, stat numbers, section labels, icons, CTAs, and the Kong logo. Never introduce additional accent colors — reach for the silver/muted/card grays instead when you need a second tone.

## Avoid (common mistakes)

- Generic color palettes — always use Kong colors.
- Arial, Times, or other non-Kong fonts as primary.
- Repeating the same layout across slides — vary columns, cards, and callouts.
- Centering body text — left-align paragraphs and lists; center only titles.
- Defaulting to bullets on white — every slide needs visual elements.
- Underline accents under titles — a hallmark of AI-generated slides.
- Stock photography — solid backgrounds or branded imagery only.
- Secondary accent colors beyond the Kong palette.
- Rounded rectangles with accent borders.
- Skipping the Kong footer bar on content slides.
- Skipping text-box padding reset (`margin: 0`) when aligning text with shapes.
