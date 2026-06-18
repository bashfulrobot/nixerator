---
name: svg-specialist
description: Author, edit, and optimize production-grade SVG — clean geometry and path data, accessible icon systems with reusable symbols, gradients/filters/clipping, CSS and SMIL animation, and framework (React/Vue/Svelte) integration. Use this skill whenever the work touches a .svg file or inline SVG markup: drawing or hand-tuning vector shapes and paths, building or refactoring an icon set or sprite sheet, shrinking SVG file size with SVGO, making a vector accessible to screen readers, animating a graphic, theming an icon to follow text colour, or embedding an SVG into a component. Trigger even when the user doesn't say "SVG" by name — "make this logo scale crisply", "this icon is huge / won't theme", "animate this checkmark", "turn this graphic into a React component", or "why is my vector blurry / clipped" all belong here.
---

# SVG Specialist

SVG is code, not a binary blob. That is the whole advantage: every shape is editable text, it scales without loss, it themes with CSS, it animates, and it compresses well. Most SVG problems come from treating it like an opaque export — so the core discipline is to read the markup, understand the coordinate system, and make small, intentional changes that preserve the parts you don't mean to touch.

## First, orient yourself in the file

Before changing anything, read the root `<svg>` element and answer three questions. They determine whether every later edit lands where you expect:

1. **What is the `viewBox`?** `viewBox="minX minY width height"` defines the internal coordinate system. All `x`/`y`/`d`/`cx` values are in *these* units, not pixels. A `viewBox="0 0 24 24"` icon lives on a 24×24 grid no matter what size it renders at.
2. **Are `width`/`height` set, and do they fight the viewBox?** Fixed `width`/`height` pin the render size and block CSS sizing. For anything meant to scale (icons, responsive art), prefer keeping the `viewBox` and dropping or overriding fixed dimensions so the container controls size.
3. **What's the coordinate convention?** Y increases *downward*. `transform`, nested coordinate systems, and `preserveAspectRatio` all compose — a shape that looks "off by a bit" is usually a transform or a viewBox mismatch, not a wrong path.

**When editing existing SVG, change incrementally and preserve the rest.** Don't rewrite a whole `d` attribute to nudge one point; find the relevant command and adjust it. Don't restructure groups to add one shape. Keep the `viewBox` and existing coordinate system unless the explicit goal is to change them — re-coordinatising silently breaks every consumer that positioned or clipped the graphic. State the visual impact of each change ("moved the dot 2 units right", "tightened the viewBox to the artwork bounds") so the user can predict the result without rendering.

## Geometry and path data

Reach for the simplest primitive that expresses the shape — `<rect>`, `<circle>`, `<ellipse>`, `<line>`, `<polyline>`, `<polygon>` — before hand-writing a `<path>`. They're readable, self-documenting, and easier to tweak.

When you do need `<path>`, the `d` command vocabulary:

- `M x y` moveto (start a subpath) · lowercase = relative to current point
- `L x y` lineto · `H x` / `V y` horizontal/vertical line
- `C x1 y1 x2 y2 x y` cubic Bézier · `S` smooth cubic (reflects previous control point)
- `Q x1 y1 x y` quadratic Bézier · `T` smooth quadratic
- `A rx ry x-axis-rotation large-arc-flag sweep-flag x y` elliptical arc
- `Z` closepath (back to subpath start)

Practical guidance:
- **Use relative commands (lowercase) for shapes you'll move or repeat** — the subpath stays self-contained and you can reposition with a single leading `M`.
- **Round coordinates to a sane precision.** Two decimals is plenty for screen graphics; `12.847291` is noise that bloats the file and obscures intent. (SVGO automates this — see optimization below.)
- **Keep numbers on a clean grid where you can.** Icons authored on a 24×24 grid with integer-ish coordinates stay crisp and easy to reason about.
- For symmetric or smooth curves, use `S`/`T` so control points stay consistent — manually mismatched control points cause the kinks people describe as "the curve looks lumpy".

## Accessibility — make the vector legible to assistive tech

This is where most SVG falls short, and it's cheap to fix. The right markup depends on whether the SVG is *content* or *decoration*:

**Meaningful graphic** (a logo, a chart, an icon that conveys state):
```svg
<svg viewBox="0 0 24 24" role="img" aria-labelledby="t d">
  <title id="t">Delete</title>
  <desc id="d">Trash can icon — removes the selected item</desc>
  ...
</svg>
```
- `role="img"` makes assistive tech treat the whole SVG as a single image rather than walking its shapes.
- `<title>` is the accessible name (also the native tooltip); `<desc>` is the longer description. Reference both from `aria-labelledby`. A `<title>` alone is often enough for a simple icon.

**Purely decorative** (the adjacent text already says everything):
```svg
<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">...</svg>
```
- `aria-hidden="true"` removes it from the accessibility tree; `focusable="false"` stops IE/legacy Edge from tab-stopping on it.

**Interactive** (a clickable icon button): put the accessible name on the *control*, not just the SVG — `<button aria-label="Delete">` with an `aria-hidden` icon inside is the robust pattern.

Don't rely on `fill`/colour alone to convey meaning; pair it with a label or text. State conveyed only by colour is invisible to screen readers and to colour-blind users.

## Theming — let the SVG follow its context

The trick that makes an icon set maintainable is `currentColor`: it resolves to the element's CSS `color`, so the icon inherits text colour for free.

```svg
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
  <path d="M5 12 l5 5 l9 -9" />
</svg>
```
Now `color: red` on any ancestor (hover, dark mode, active nav item) recolours the icon with no SVG edit. **Strip hard-coded `fill="#333"`-style colours from icons meant to theme** — replace with `currentColor` (or `fill="none"` + `stroke="currentColor"` for line icons). For multi-colour icons, expose the variable parts via CSS custom properties (`fill="var(--accent, currentColor)"`) so consumers can override selectively.

## Icon systems — reuse with `<symbol>` and `<use>`

Repeating full icon markup everywhere is the SVG equivalent of copy-paste. Define each icon once as a `<symbol>` (carrying its own `viewBox`) and instantiate with `<use>`:

```svg
<!-- sprite.svg or inlined once per page -->
<svg style="display:none" aria-hidden="true">
  <symbol id="icon-check" viewBox="0 0 24 24">
    <path d="M5 12 l5 5 l9 -9" fill="none" stroke="currentColor" stroke-width="2"/>
  </symbol>
</svg>

<!-- anywhere, any size, inherits color -->
<svg class="icon" aria-hidden="true"><use href="#icon-check"/></svg>
```
- The `<symbol>`'s own `viewBox` lets each `<use>` instance scale independently.
- `currentColor` inside the symbol still works through `<use>`, so one definition themes everywhere.
- For a cross-file sprite, `<use href="/sprite.svg#icon-check"/>` works same-origin. Inlining the sprite avoids a request and sidesteps cross-origin/styling limits of external `<use>`.

This is the heart of an "icon system": one sprite, many cheap references, all themeable. When refactoring an ad-hoc set of icons, consolidating duplicated markup into symbols is usually the highest-value change.

## Styling — gradients, filters, clipping, masking

These live in `<defs>` (definitions that don't render directly) and are referenced by `id`:

- **Gradients** — `<linearGradient>` / `<radialGradient>` with `<stop offset stop-color>`, referenced via `fill="url(#grad)"`. Keep `gradientUnits` in mind: `objectBoundingBox` (default) scales the gradient to the shape; `userSpaceOnUse` pins it to the coordinate system.
- **Filters** — `<filter>` with primitives like `feGaussianBlur`, `feDropShadow`, `feColorMatrix`, referenced via `filter="url(#f)"`. Powerful but the most expensive thing in SVG to render — use sparingly on animated or numerous elements.
- **Clipping** — `<clipPath>` hard-cuts to a shape (in or out, no partial). Referenced via `clip-path="url(#c)"`.
- **Masking** — `<mask>` uses luminance/alpha for *soft* edges and gradient fades, where clipping can only do hard boundaries.

Rule of thumb: **clip for crisp geometric cutoffs, mask for soft or gradient-based reveals.** If something is "getting cut off unexpectedly", suspect an over-tight `clipPath` or a `viewBox`/`overflow` interaction first.

For deeper filter recipes (drop shadows, glows, duotone via `feColorMatrix`) and gradient-unit gotchas, read `references/styling-and-filters.md`.

## Optimization

Hand-authored and exported SVGs carry editor cruft — metadata, comments, redundant precision, empty groups, inline styles that could be attributes. SVGO removes it safely and can cut file size substantially without changing rendering.

`node`/`npx` are available, so no install is needed:

```bash
npx svgo input.svg -o output.svg          # single file
npx svgo -f icons/ -o icons-min/          # whole folder
npx svgo --config svgo.config.mjs in.svg  # with a tuned config
```

A ready-to-use config that's safe for icons (preserves `viewBox`, keeps `currentColor`, doesn't merge paths in a way that breaks targeting) ships at `assets/svgo.config.mjs` — copy it into the project and point `--config` at it.

**The one setting that bites people:** the default `removeViewBox` plugin strips `viewBox` when `width`/`height` are present, which kills scalability. The bundled config disables it. When in doubt, confirm the `viewBox` survived optimization. For the full plugin rundown and when to deviate, read `references/optimization.md`.

## Animation

Two viable approaches; pick by what's moving and where:

- **CSS animation/transitions** — the default. Animate `transform`, `opacity`, `stroke-dashoffset` (the line-drawing effect), gradient stops, etc. It's GPU-friendly for `transform`/`opacity`, easy to trigger on `:hover`/state, and degrades gracefully.
- **SMIL** (`<animate>`, `<animateTransform>`, `<animateMotion>`) — self-contained inside the SVG, no CSS/JS needed, and the only built-in way to animate along a path (`animateMotion`). Widely supported in modern browsers but historically deprecated-then-revived; for a graphic that must animate standalone (e.g. an `.svg` used as an `<img>`), SMIL is the only option that survives, since CSS in an externally-referenced SVG and JS are both sandboxed away.

**Always gate non-essential motion behind `prefers-reduced-motion`** — vestibular-sensitive users can be physically harmed by unexpected movement, and it's a one-block fix:
```css
@media (prefers-reduced-motion: reduce) {
  .animated-icon { animation: none; }
}
```
For the line-draw (`stroke-dasharray`/`stroke-dashoffset`) technique, `animateMotion` along a path, and reduced-motion patterns, read `references/animation.md`.

## Framework integration

- **React/JSX** — inline SVG becomes a component. Attributes camelCase (`strokeWidth`, `clipPath`, `fillRule`); `class` → `className`. Drive colour/size via props and `currentColor` rather than hard-coding, so one component serves every use. Spread `...props` onto the root `<svg>` so consumers can pass `aria-label`, `onClick`, `className`.
- **Vue/Svelte** — inline SVG works directly in templates; bind attributes with the framework's normal syntax. `currentColor` + a `color` style/prop is still the cleanest theming path.
- **`<img src>` vs inline** — `<img>` is cacheable and isolated but can't be themed by page CSS and won't run external CSS/JS animation (SMIL still runs). Inline SVG is fully styleable/scriptable but adds to document weight and isn't cached separately. Choose inline when you need theming/interaction, `<img>` for static decorative art you want cached.

A common pitfall: pasting raw SVG into JSX fails to compile because of `class`, `stroke-width`, etc. Convert kebab attributes to camelCase (except data-/aria- which stay kebab) and `class`→`className`.

## Working approach

- Read before you edit; name the `viewBox` and coordinate system out loud.
- Prefer the simplest primitive; reach for `<path>` only when shapes demand it.
- Make accessibility a default, not an afterthought — decide content-vs-decoration up front.
- Theme with `currentColor`; consolidate repeated icons into `<symbol>`/`<use>`.
- Optimize with SVGO, and verify the `viewBox` survived.
- Gate motion behind `prefers-reduced-motion`.
- Describe the visual effect of each change so the user can predict the result.
