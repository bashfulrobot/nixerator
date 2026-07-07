# Drift between this skill and other Kong-branded skills

This skill was built directly from Kong's official **2026 v1.1** Brand Guidelines PDF and Press Kit. Several Kong-branded skills already in this environment predate that refresh (or copy-pasted values that drifted from it independently). This file records what was actually found on inspection, and what was changed.

**Don't assume a mismatch is a mistake.** The first pass through this file (see git history) flagged several values as drift before actually inspecting the artifacts behind them. On closer inspection two of those flags were wrong: `kong-success-plan-pptx`'s binary template turned out to already use the *exact* official hex codes, and "Funnel Display"/"Urbanist" turned out to be real Google Fonts genuinely used in authentic Kong-authored templates, not fabrications. Verify before "fixing."

## Findings, by skill

### `kong-success-plan-pptx` — already correct, no changes made
Inspected `templates/kong-success-plan-template.pptx` directly (`ppt/slides/*.xml`, not just `build.py`, since the brand values live in the binary template, not the script). It uses `#000F06` and `#001408` (both correct — see the canonical-value note in `colors.md`) and `#B7BDB5` (Bay) directly on shapes, plus Funnel Sans / Funnel Sans ExtraBold / Funnel Sans Medium / Space Grotesk / Urbanist as fonts. This is the most accurate Kong-branded artifact in this environment. `build.py` only replaces text via shape IDs — it never touches color or font, so there was nothing to change.

### `kong-revealjs-theme` — one real fix (code font), rest is intentional
`theme/kong.css` opens with: *"Reproduced from the official 'Kong \[Theme] template slides 2026 \[dark]' deck."* That's a real official source, not a guess — so its `--kong-bg: #07120A`, `--kong-border-green: #1F3D1F`, `--kong-card-dark: #0D1A0E` were left **unchanged**. These sit a shade lighter than the guidelines PDF's flat `#000F06` because the actual template uses a near-black (`#000000`) content panel with a dark-green *frame* around it — the frame color needs to read as distinct from pure black on screen, which the guidelines PDF's single flat swatch doesn't have to account for. Overwriting it to `#000F06` would likely make the frame invisible against the panel. A code comment now points to `kong-branding/references/colors.md` so this isn't mistaken for drift again.

What *was* wrong: the code block font-family was `'JetBrains Mono', 'Fira Code'` — neither is Kong's typeface. The official guide is unambiguous that **Roboto Mono** is the code typeface, and nothing about this deck theme suggested JetBrains Mono was an intentional substitution (unlike the dark-green shades, there's no "reproduced from an official deck" note attached to it). Fixed: swapped to `'Roboto Mono'`, added it to the Google Fonts `@import`, and added a `--kong-font-button: 'Space Grotesk', ...` variable applied to the CTA-style badge/pill classes (`.kong-badge`, `.kong-pt-pill`, `.kong-gi-eyebrow`) per the guide's explicit "buttons/CTAs only" role for Space Grotesk.

### `kong-pptx` — the dangling reference is now real
`SKILL.md` pointed at `references/kong-theme.md` for the full palette/font stack/footer code, but that file never existed. Created it, carrying forward the palette this skill already documented in `SKILL.md` (dark theme near-black `000000`/light theme warm gray-green `D7DED4` — pptx-specific choices for slide-background contrast, left as-is for the same "reproduced from a real template, not a guess" reasoning as the reveal theme) plus the confirmed Funnel Display / Urbanist supplementary faces and the `addKongFooter()` helper the SKILL.md already referenced but never defined. Points to `kong-branding` for the base logos/tokens.

### `renewal-projection` — internal inconsistency, now fixed
Its `deck-build.md` palette object used `border: "1A3A1A"`, but the skill it explicitly says it inherits from (`kong-revealjs-theme` / `kong-pptx`) uses `1F3D1F`. This wasn't drift from the official guide (the guide doesn't specify a border color at all) — it was two of *your own* skills disagreeing with each other despite one claiming to borrow from the other. Fixed: aligned to `1F3D1F` to match `kong-revealjs-theme`'s value, since that's the skill renewal-projection cites as its source.

### `kong-doc-build` — out of scope, different repository
Lives in the `kong-skills` plugin marketplace (`Kong/kong-skills` on GitHub per `cfg/plugin-config.nix`), not in this `nixerator` repo. Its `assets/brand/MANIFEST.json` is still an empty registry with no images populated — flagged here for whoever owns that repo, not fixed in this pass since it isn't this repo's code to change.

## Remaining open question

Neither `kong-pptx`'s near-black `000000` slide background nor `kong-revealjs-theme`'s `#07120A`/`#0D1A0E` panel/frame colors were forced to the guidelines PDF's flat `#000F06`. Both are plausibly deliberate on-screen adaptations backed by real templates, and changing them would risk visually altering decks already built with these themes for essentially no benefit (the guidelines PDF's swatch page is a print/summary reference, not a pixel-exact screen spec). If you have access to an actual current "Kong template slides 2026" Google Slides file, diffing its exported colors against these CSS variables would settle this definitively — until then, treat the difference as intentional, not a bug.
