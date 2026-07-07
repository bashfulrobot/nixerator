# Drift between this skill and other Kong-branded skills

This skill was built directly from Kong's official **2026 v1.1** Brand Guidelines PDF and Press Kit. Several Kong-branded skills already in this environment predate that refresh (or copy-pasted values that drifted from it independently) and disagree with it in places. This file exists so that:

1. You know which value to trust when two Kong skills disagree (**this one**).
2. A future pass can point those skills at `assets/tokens/kong-brand.{json,css}` and the logo files here instead of re-deriving values inline.

This consolidation was deliberately *not* done as part of building this skill — the deck-producing skills (`kong-pptx`, `kong-revealjs-theme`, binary `.pptx` templates) carry real production risk if their brand values change out from under existing decks. Treat this as a scoped follow-up, not an oversight.

## Known mismatches

| Value | Official (this skill) | `kong-revealjs-theme` | `kong-pptx` | `renewal-projection` | `kong-doc-build` (plugin marketplace) |
|---|---|---|---|---|---|
| Dark base | `#000F06` | `#07120A` (bg), `#0D1A0E` (card-dark) | — (uses `000000` as bg) | `0D1A0E` (cardDark) | `001408` |
| Border green | `#4A4D49` (neutral-700) | `#1F3D1F` | — | `1A3A1A` | — |
| Body gray (light theme) | neutral-900 `#101110` | — | `42453E` | — | `434343` |
| Accent | `#CCFF00` ✅ | `#CCFF00` ✅ | `CCFF00` ✅ | `CCFF00` ✅ | `CCFF00` ✅ |
| Primary typeface | Funnel Sans ✅ | Funnel Sans + **Funnel Display** (not in official guide) | Funnel Sans + **Funnel Display** + **Urbanist** (neither in official guide) | Funnel Sans ✅ | Funnel Sans ✅ |
| Code typeface | Roboto Mono | **JetBrains Mono, Fira Code** | — | — | — |
| Button typeface | Space Grotesk | — (not distinguished) | — (not distinguished) | — | — |
| Footer right-side notice | *(not specified by official guide — house style)* | "NOT TO BE SHARED EXTERNALLY" | "NOT TO BE SHARED EXTERNALLY" | "INTERNAL DRAFT · NOT FOR EXTERNAL USE" | — |

Everything agrees on the accent `#CCFF00` and on Funnel Sans as the base typeface — those were never in question. The drift is concentrated in the *dark* end of the palette (three different "near-black-green" values across four skills) and in typefaces the official 2026 guide doesn't actually specify (Funnel Display, Urbanist, JetBrains Mono, Fira Code) — those were presumably reasonable choices at the time, made before this brand refresh existed or without the official guide to check against.

## Known gaps (not drift, just broken)

- `kong-pptx/SKILL.md` instructs the reader to open `references/kong-theme.md` for the full palette/font stack/footer code/`addKongFooter()` helper — **that file doesn't exist** in `modules/apps/cli/claude-code/config/skills/kong-pptx/`. Fix: either create it as a thin pointer to `kong-branding`'s tokens, or update the pointer.
- `kong-doc-build`'s `assets/brand/MANIFEST.json` (plugin marketplace copy) is a schema/comment with no actual image entries populated — a logo/asset registry with nothing registered.

## Suggested alignment checklist (future pass, not done here)

1. Point `kong-revealjs-theme/theme/kong.css`, `kong-pptx/SKILL.md`'s inline palette, and `renewal-projection/references/deck-build.md`'s JS palette object at `kong-branding/assets/tokens/kong-brand.json` (or copy the resolved values in, with a comment citing this file) rather than each carrying its own numbers.
2. Reconcile the dark-base and border-green values to the official `#000F06` / neutral ramp, or explicitly document why the deck skills intentionally use a darker/more saturated variant for on-screen contrast (a real possibility — `#000F06` at large fill can look flat on some displays, and `07120A`/`0D1A0E` may have been a considered adjustment, not a mistake). Don't silently overwrite without checking whether that was intentional.
3. Copy or symlink the logomark/wordmark PNGs from `kong-branding/assets/logos/` into the deck skills' `assets/images/` if they should be pulling from a single source rather than maintaining separate exports.
4. Fix the dangling `kong-pptx/references/kong-theme.md` reference.
5. Either populate `kong-doc-build`'s `MANIFEST.json` from this skill's logo set, or point it at this skill directly.
6. Standardize the footer confidentiality notice wording across decks, or confirm the differences ("NOT TO BE SHARED EXTERNALLY" vs "INTERNAL DRAFT · NOT FOR EXTERNAL USE") are intentionally different for different document sensitivity levels — in which case document that as a house convention rather than drift.

None of this blocks using `kong-branding` today — it's additive. It just means an audit run with `scripts/brand-audit.py` against an *existing* Kong deck built with one of these older skills may flag values that were fine under the old internal convention but don't match the official 2026 guide. Use judgment: flag it, but don't treat every flagged hex as an error until you've checked this table.
