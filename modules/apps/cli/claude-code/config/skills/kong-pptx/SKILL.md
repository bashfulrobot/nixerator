---
name: kong-pptx
description: "Use this skill any time a .pptx file is involved in any way -- as input, output, or both. This includes: creating slide decks, pitch decks, or presentations; reading, parsing, or extracting text from any .pptx file (even if the extracted content will be used elsewhere, like in an email or summary); editing, modifying, or updating existing presentations; combining or splitting slide files; working with templates, layouts, speaker notes, or comments. Trigger whenever the user mentions \"deck,\" \"slides,\" \"presentation,\" or references a .pptx filename, regardless of what they plan to do with the content afterward. If a .pptx file needs to be opened, created, or touched, use this skill. This skill ALWAYS takes priority over the default pptx skill because it includes Kong brand theming."
---

# PPTX Skill

## Quick Reference

| Task | Guide |
|------|-------|
| Read/analyze content | `python -m markitdown presentation.pptx` |
| Edit or create from template | Read [editing.md](editing.md) |
| Create from scratch | Read [pptxgenjs.md](pptxgenjs.md) |

---

## Theme Selection (REQUIRED for all new presentations)

All new presentations use the **Kong brand theme** by default. There are two variants:

- **Dark** (default) -- near-black backgrounds, white text, neon green accents
- **Light** -- warm gray-green backgrounds, dark text, neon green accents

**If the user does not specify light or dark, use Dark.**

If the request is ambiguous (e.g. "make it bright" or "professional look"), ask:

> "Do you want the dark or light Kong theme? Dark is the default."

Before creating any new presentation, **read [references/kong-theme.md](references/kong-theme.md)** for the complete Kong color palette, font stack, slide patterns, footer bar code, and brand rules. Follow those rules exactly. Do not use generic palettes, fonts, or layouts.

---

## Reading Content

```bash
# Text extraction
python -m markitdown presentation.pptx

# Visual overview
python scripts/thumbnail.py presentation.pptx

# Raw XML
python scripts/office/unpack.py presentation.pptx unpacked/
```

---

## Editing Workflow

**Read [editing.md](editing.md) for full details.**

1. Analyze template with `thumbnail.py`
2. Unpack > manipulate slides > edit content > clean > pack

---

## Creating from Scratch

**Read [pptxgenjs.md](pptxgenjs.md) for full details.**

Use when no template or reference presentation is available. Always apply the Kong theme from [references/kong-theme.md](references/kong-theme.md).

---

## Design Rules (Kong-Branded)

The full Kong brand spec lives in [references/kong-theme.md](references/kong-theme.md). Here is the summary:

### Core Palette

**Dark theme (default):**
- Background: `000000` (near-black)
- Primary text: `FFFFFF` (white)
- Accent: `CCFF00` (Kong Neon Green)
- Secondary text: `AAB4BB` (silver)
- Muted text: `8A8F89`
- Card fills: `30352F`

**Light theme:**
- Background: `D7DED4` (warm gray-green)
- Primary text: `42453E` (dark charcoal-green)
- Accent: `CCFF00` (Kong Neon Green)
- Secondary text: `737772`
- Muted text: `666666`
- Card fills: `42453E`

### Fonts

Primary family: **Funnel Sans** (SemiBold for titles, Medium for subheadings, Regular for body, Light for captions). Hero titles on title slides can use **Funnel Display**. Secondary: **Urbanist** (sparingly).

### Typography Scale

| Element | Size | Weight |
|---------|------|--------|
| Hero title | 60-72pt | Bold |
| Slide title | 36pt | Bold |
| Section label | 9-10pt | Bold, uppercase, accent color |
| Subtitle | 22-24pt | Bold |
| Body | 14-16pt | Regular |
| Stats | 48-72pt | Bold, accent color |
| Footer | 7-8pt | Light |

### Layout Patterns

Every content slide gets a **Kong footer bar** at y=5.27" with: Kong logo mark, "AI CONNECTIVITY" in green, "© Kong Inc.", confidentiality notice, and slide number. See kong-theme.md for the reusable `addKongFooter()` function.

**Slide types to use:**
- Title slide (hero text, Kong logo, subtitle, date, speaker)
- Section divider (bold statement, one word highlighted in green)
- Stats/metrics grid (large green numbers, muted descriptions)
- Content slides (section label + title + body)
- Numbered steps / values (1, 2, 3 in green with descriptions)
- Timeline (horizontal milestones)
- Closing / Thank You (contact info, Kong wordmark background)

### Accent Color Usage

The neon green `CCFF00` is the ONLY accent color. Use it for: key words in titles, stat numbers, section labels, icons, CTAs, and the Kong logo. Never introduce additional accent colors.

### Avoid (Common Mistakes)

- **Do not use generic color palettes** -- always use Kong colors
- **Do not use Arial, Times, or other non-Kong fonts** as primary
- **Do not repeat the same layout** -- vary columns, cards, and callouts across slides
- **Do not center body text** -- left-align paragraphs and lists; center only titles
- **Do not default to bullets on white** -- every slide needs visual elements
- **Do not add underline accents under titles** -- hallmark of AI-generated slides
- **Do not use stock photography** -- use solid backgrounds or branded imagery only
- **Do not introduce secondary accent colors** beyond the Kong palette
- **Do not use rounded rectangles with accent borders**
- **Do not forget the Kong footer bar** on content slides
- **Do not skip text box padding reset** -- set `margin: 0` when aligning text with shapes

---

## QA (Required)

**Assume there are problems. Your job is to find them.**

Your first render is almost never correct. Approach QA as a bug hunt, not a confirmation step. If you found zero issues on first inspection, you weren't looking hard enough.

### Content QA

```bash
python -m markitdown output.pptx
```

Check for missing content, typos, wrong order.

**When using templates, check for leftover placeholder text:**

```bash
python -m markitdown output.pptx | grep -iE "\bx{3,}\b|lorem|ipsum|\bTODO|\[insert|this.*(page|slide).*layout"
```

If grep returns results, fix them before declaring success.

### Visual QA

**Use subagents** -- even for 2-3 slides. You've been staring at the code and will see what you expect, not what's there. Subagents have fresh eyes.

Convert slides to images (see [Converting to Images](#converting-to-images)), then use this prompt:

```
Visually inspect these slides. Assume there are issues -- find them.

Look for:
- Overlapping elements (text through shapes, lines through words, stacked elements)
- Text overflow or cut off at edges/box boundaries
- Decorative lines positioned for single-line text but title wrapped to two lines
- Source citations or footers colliding with content above
- Elements too close (< 0.3" gaps) or cards/sections nearly touching
- Uneven gaps (large empty area in one place, cramped in another)
- Insufficient margin from slide edges (< 0.5")
- Columns or similar elements not aligned consistently
- Low-contrast text (e.g., light gray text on cream-colored background)
- Low-contrast icons (e.g., dark icons on dark backgrounds without a contrasting circle)
- Text boxes too narrow causing excessive wrapping
- Leftover placeholder content
- Kong brand violations (wrong colors, missing footer, wrong fonts)

For each slide, list issues or areas of concern, even if minor.

Read and analyze these images -- run `ls -1 "$PWD"/slide-*.jpg` and use the exact absolute paths it prints:
1. <absolute-path>/slide-N.jpg -- (Expected: [brief description])
2. <absolute-path>/slide-N.jpg -- (Expected: [brief description])
...

Report ALL issues found, including minor ones.
```

### Verification Loop

1. Generate slides > Convert to images > Inspect
2. **List issues found** (if none found, look again more critically)
3. Fix issues
4. **Re-verify affected slides** -- one fix often creates another problem
5. Repeat until a full pass reveals no new issues

**Do not declare success until you've completed at least one fix-and-verify cycle.**

---

## Converting to Images

Convert presentations to individual slide images for visual inspection:

```bash
python scripts/office/soffice.py --headless --convert-to pdf output.pptx
rm -f slide-*.jpg
pdftoppm -jpeg -r 150 output.pdf slide
ls -1 "$PWD"/slide-*.jpg
```

**Pass the absolute paths printed above directly to the view tool.** The `rm` clears stale images from prior runs. `pdftoppm` zero-pads based on page count: `slide-1.jpg` for decks under 10 pages, `slide-01.jpg` for 10-99, `slide-001.jpg` for 100+.

**After fixes, rerun all four commands above** -- the PDF must be regenerated from the edited `.pptx` before `pdftoppm` can reflect your changes.

---

## Dependencies

- `pip install "markitdown[pptx]"` - text extraction
- `pip install Pillow` - thumbnail grids
- `npm install -g pptxgenjs` - creating from scratch
- LibreOffice (`soffice`) - PDF conversion (auto-configured for sandboxed environments via `scripts/office/soffice.py`)
- Poppler (`pdftoppm`) - PDF to images
