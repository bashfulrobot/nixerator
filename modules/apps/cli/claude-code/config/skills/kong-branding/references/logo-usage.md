# Kong logo usage (2026 v1.1)

Source: Kong Brand Guidelines PDF ("Logomark", "Logotype", "Themes" sections) + Press Kit. Bundled files at `assets/logos/`.

## The two marks

- **Logomark** ("the Walker") — the emblem. A singular, bold mark built from distinct elements that read as one moving shape — Kong's shorthand for "independent parts, intelligently connected, moving as one." Use it standalone for compact placements (favicon, app icon, avatar, a corner mark) where the wordmark won't fit or would compete with other content.
- **Logotype** — the "Kong" wordmark. Bold, geometric, legible at both digital and print sizes. Use it wherever the brand needs to be named, not just marked.

Kong also publishes a **primary lockup** that combines mark + a colored background plate (dark-green-on-lime and lime-on-dark-green variants) — see `assets/logos/for-light-backgrounds/svg/primary-*-BG.svg`. Reach for that when you need a self-contained, drop-in logo badge rather than composing mark + type yourself.

## Bundled files

The press kit's own organization is preserved (it splits by *what background you're placing the logo on*, not by light/dark theme of the mark itself — don't confuse the two):

```
assets/logos/
├── for-light-backgrounds/{svg,png,eps,ai}/   # logos meant to sit on a light surface
└── for-dark-backgrounds/{svg,png,eps,ai}/    # logos meant to sit on a dark surface
```

Each folder has `Kong-Logomark[-transparent]` and `Kong-Logotype[-transparent]` in each format, plus the `secondary-*-transparent` PNGs and the `primary-*-BG` combined lockups in the light-background SVG/PNG set. Prefer SVG for anything digital (scales cleanly, small file size); PNG when the target doesn't support vectors; EPS/AI only for print production handoff.

Pick the folder by the actual background color behind the logo, not by your product's overall dark/light theme — a logo on a white card inside an otherwise-dark page still needs the light-background version.

## Themes

Four surface themes govern how the mark/lockup appears: **Dark** and **Electric** are priority usage (default to these); **Bay** and **White** are supported alternates for print, documents, or light-mode hosts. See `colors.md` for the exact hexes behind each theme.

## Clear space and sizing

The guidelines define clear space as **1× the logomark's own key unit** on every side — don't crowd the mark with text, other logos, or a container edge closer than that. There's no published numeric minimum size in the extracted guidelines; use judgment (if the Walker's internal detail starts to blur or the wordmark's letterforms start touching, you're too small) and prefer the logomark alone over a shrunk lockup at small sizes.

## Rules — verbatim from Kong's trademark guidelines (`?mode=agent`)

**Permitted:**
- "works with Kong" or "compatible with Kong" in text, if accurate.
- Linking to Kong's site using the logo, if you're a Kong user.
- Educational/instructional use in eBooks, guides, publications, conference material — **provided you include**: *"(Title) is not affiliated with or otherwise sponsored by Kong, Inc."*

**Prohibited:**
- Editing, changing, distorting, recoloring, or reconfiguring the logo in any way.
- Using "Kong" in a company name, product name, service name, website name, or trade name.
- Incorporating Kong's logo into another logo.
- Domain names containing "kong" or a confusingly similar word.
- Kong branding on merchandise / t-shirts / swag produced by a third party.
- Any confusing or misleading use suggesting Kong sponsorship or endorsement.
- Using the logo on a book cover without permission.

**Required when you do use it:**
- Check with Kong (**design@konghq.com**) first for use on outside websites, products, packaging, manuals, or any commercial/product context.
- Your own name/logo must be more prominent than Kong's in any co-branded placement.
- Include the affiliation disclaimer in educational materials (verbatim string above).

By using any Kong brand element you're implicitly agreeing to Kong's Terms of Service and these guidelines — treat "check with Kong first" as a real gate for anything customer- or public-facing, not a formality. See `trademark-usage.md` for the full source text and `drift-and-consolidation.md` if you're reconciling this against an older Kong-branded asset.
