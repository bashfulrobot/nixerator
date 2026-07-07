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

The full Kong brand spec — palette, fonts, typography scale, footer bar code, logo assets, slide types, and things to avoid — lives in [references/kong-theme.md](references/kong-theme.md). Read it before creating any new presentation; don't rely on memory of a prior read, since it's the single place these values are maintained.

The one-line version: dark theme is near-black `000000` with `CCFF00` as the only accent and white/silver/muted text; light theme is warm gray-green `D7DED4` with dark charcoal-green text. Funnel Sans is the primary typeface everywhere except code (Roboto Mono) and CTAs (Space Grotesk). Base brand documentation (colors, full type system, logo files, trademark rules) lives in the `kong-branding` skill — `kong-theme.md` is this skill's pptx-specific application of it.

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
