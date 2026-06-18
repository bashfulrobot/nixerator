# SVG styling — gradients, filters, clipping, masking

Recipes and gotchas for the visual-effect machinery that lives in `<defs>`. Everything here is defined once and referenced by `id`, so the same gradient/filter can serve many shapes.

## Gradients

```svg
<defs>
  <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0%"  stop-color="#6366f1"/>
    <stop offset="100%" stop-color="#ec4899"/>
  </linearGradient>
  <radialGradient id="r" cx="50%" cy="50%" r="50%">
    <stop offset="0%" stop-color="#fff" stop-opacity="0.9"/>
    <stop offset="100%" stop-color="#fff" stop-opacity="0"/>
  </radialGradient>
</defs>
<rect width="100" height="100" fill="url(#g)"/>
```

**The units gotcha:** `gradientUnits` defaults to `objectBoundingBox`, where `x1..y2` are fractions (0–1) of the shape's bounding box — the gradient scales and moves with each shape that uses it. Switch to `userSpaceOnUse` to pin the gradient to the SVG coordinate system instead (so multiple shapes share one continuous gradient, or the gradient stays fixed while shapes move). Mismatched expectations here cause "the gradient looks squished/offset on this shape" — it's almost always the units mode.

`stop-opacity` on stops is how you fade a gradient to transparent (e.g. a soft vignette or a fade-out edge).

## Filters

```svg
<defs>
  <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
    <feDropShadow dx="0" dy="2" stdDeviation="3" flood-opacity="0.3"/>
  </filter>
  <filter id="glow">
    <feGaussianBlur stdDeviation="2.5" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>
<path filter="url(#shadow)" d="..."/>
```

Key primitives:
- `feGaussianBlur` — blur; the building block of shadows and glows.
- `feDropShadow` — shadow in one primitive (blur + offset + colour).
- `feColorMatrix` — recolour/duotone/grayscale via a 4×5 matrix or `type="saturate"|"hueRotate"`.
- `feOffset`, `feFlood`, `feComposite`, `feMerge` — the plumbing for hand-built effects.

**Always widen the filter region.** Filters clip to the filter's `x/y/width/height` (default `-10% -10% 120% 120%`), so a blur or shadow that extends past that box gets cut off. Set a generous region (`x="-20%" ... width="140%"`) when the effect spreads.

**Cost:** filters are the most expensive thing SVG renders. Avoid putting them on many elements or on anything animated every frame — composite the effect into one element, or pre-render to an image, if performance suffers.

## Clipping vs masking

Both restrict what's visible, but differently — pick by edge type:

```svg
<defs>
  <clipPath id="c"><circle cx="50" cy="50" r="40"/></clipPath>
  <mask id="m">
    <rect width="100" height="100" fill="white"/>      <!-- visible -->
    <circle cx="50" cy="50" r="30" fill="black"/>       <!-- punched out -->
  </mask>
</defs>
<image href="photo.jpg" width="100" height="100" clip-path="url(#c)"/>
<rect width="100" height="100" fill="url(#g)" mask="url(#m)"/>
```

- **`clipPath`** is a hard geometric cut — a pixel is fully in or fully out. Crisp, cheap, no anti-aliased falloff. Use for "show only this shape's region".
- **`mask`** uses luminance (white = opaque, black = transparent, grey = partial) or alpha, so it does **soft** edges, gradient fades, and feathered reveals — anything clipping can't.

Diagnosing "my graphic is getting cut off": check, in order, an over-tight `clipPath`, a too-small filter region, the root `viewBox` cropping the artwork, and `overflow` on a nested SVG (defaults to hidden).

## `clipPathUnits` / `maskUnits`

Same trap as gradients: these default to `userSpaceOnUse` for `clipPath` but `objectBoundingBox` for the mask's *contents* in some cases — when a clip/mask "works at one size but not another", check whether its units are object-relative or user-space and match them to how the shape is positioned and scaled.
