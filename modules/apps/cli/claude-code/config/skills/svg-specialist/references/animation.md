# SVG animation — CSS and SMIL patterns

Concrete recipes for the techniques named in SKILL.md: line-drawing, transform/opacity motion, motion along a path, and how to keep all of it accessible. Pick CSS by default; reach for SMIL only when the SVG must animate standalone.

## Decision: CSS vs SMIL

| | CSS | SMIL (`<animate*>`) |
|---|-----|---------------------|
| Lives in | stylesheet / `<style>` | inside the SVG markup |
| Runs in external `<img src="x.svg">` | **no** (CSS & JS sandboxed) | **yes** |
| Animate along a path | no built-in | `<animateMotion>` (only native way) |
| Trigger on `:hover`/state | easy | awkward (`begin="..."` events) |
| GPU-accelerated transform/opacity | yes | renderer-dependent |
| Best for | inline SVG, UI states, most cases | self-contained standalone graphics |

Default to CSS for inline SVG in a page. Use SMIL when the graphic ships as a standalone `.svg` that must animate even when referenced as an image.

## CSS: line-drawing (the "self-drawing" stroke)

The signature SVG effect. A dashed stroke whose dash length equals the path length, with the dash offset animated from full length to zero, reveals the line as if drawn:

```svg
<path id="sig" d="M5 30 C40 5 60 55 95 30" fill="none"
      stroke="currentColor" stroke-width="3"/>
```
```css
#sig {
  stroke-dasharray: 120;   /* >= the path's total length */
  stroke-dashoffset: 120;  /* start fully "undrawn" */
  animation: draw 1.2s ease forwards;
}
@keyframes draw { to { stroke-dashoffset: 0; } }
```
Get the exact length at runtime with `path.getTotalLength()` and set both properties from it, so the dash matches the path precisely regardless of later edits.

## CSS: transform and opacity

Cheapest things to animate (compositor-friendly). For SVG, set a sensible `transform-origin` — SVG's default origin is the user-space `0 0`, not the shape's centre, so rotations/scales often need `transform-box: fill-box; transform-origin: center;`:

```css
.spinner {
  transform-box: fill-box;
  transform-origin: center;
  animation: spin 1s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
```

## SMIL: standalone animation

Self-contained, no CSS/JS needed — survives in `<img>` and as a favicon-style asset:

```svg
<circle cx="12" cy="12" r="4" fill="currentColor">
  <animate attributeName="r" values="4;6;4" dur="1.5s" repeatCount="indefinite"/>
</circle>

<g>
  <rect x="-3" y="-3" width="6" height="6" fill="currentColor">
    <animateTransform attributeName="transform" type="rotate"
      from="0 0 0" to="360 0 0" dur="2s" repeatCount="indefinite"/>
  </rect>
</g>
```

### Motion along a path (SMIL only)

```svg
<path id="track" d="M10 50 Q50 10 90 50" fill="none" stroke="#ccc"/>
<circle r="4" fill="currentColor">
  <animateMotion dur="3s" repeatCount="indefinite">
    <mpath href="#track"/>
  </animateMotion>
</circle>
```
`<mpath href="#...">` reuses an existing path as the motion track — the dot rides the curve. There is no pure-CSS equivalent that works in an externally-referenced SVG (CSS `offset-path` works only for inline SVG in the page).

## Accessibility: respect `prefers-reduced-motion`

Unexpected motion can trigger nausea, dizziness, and migraines in vestibular-sensitive users. Gate any non-essential animation:

```css
@media (prefers-reduced-motion: reduce) {
  .animated-icon,
  #sig,
  .spinner { animation: none; }
}
```
For SMIL there's no media-query hook, so if reduced-motion matters and you're using SMIL, either drive the animation from CSS instead or gate it with a small JS check (`matchMedia('(prefers-reduced-motion: reduce)')`) that pauses the SVG (`svg.pauseAnimations()`).

Keep motion purposeful and short. Looping infinite animation on UI chrome is distracting and burns battery — prefer state-triggered, finite animations (`forwards`) for icons.
