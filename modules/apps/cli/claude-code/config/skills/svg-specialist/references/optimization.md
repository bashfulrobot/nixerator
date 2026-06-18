# SVGO optimization — plugin rundown and when to deviate

Covers the SVGO plugins that matter most for hand-tuning, the failure modes to watch for, and how to verify an optimization didn't change rendering. The ready-to-use config lives at `../assets/svgo.config.mjs`.

## Running SVGO

`node`/`npx` are available, so nothing needs installing:

```bash
npx svgo input.svg -o output.svg              # single file, default plugins
npx svgo --config svgo.config.mjs in.svg      # with the tuned config
npx svgo -f src-icons/ -o dist-icons/         # whole folder
npx svgo --pretty --indent 2 in.svg -o out.svg  # readable output for review
cat in.svg | npx svgo --input - --output - > out.svg  # stdin/stdout pipe
```

`multipass: true` re-runs the plugin pipeline until the output stops shrinking — worth it, since one pass can expose further wins (e.g. an emptied group that a second pass removes).

## Plugins that change behaviour (not just size)

Most of `preset-default` is safe. These are the ones that can alter rendering or break downstream references — know what each does before trusting a blind optimization:

| Plugin | Default | Risk if left on | Guidance |
|--------|---------|-----------------|----------|
| `removeViewBox` | on | Strips `viewBox` when width/height exist → icon no longer scales | **Disable** for anything responsive. This is the #1 gotcha. |
| `cleanupIds` | on | Renames/removes ids referenced by `<use href>`, `url(#grad)`, `aria-labelledby` | Disable when ids are referenced cross-element or from JS/CSS. |
| `removeTitle` / `removeDesc` | on | Deletes accessibility text | Disable for meaningful graphics. |
| `mergePaths` | on | Fuses subpaths → can't target/animate them individually | Disable if you style or animate individual paths. |
| `removeHiddenElems` | on | Removes `display:none` elements — including a hidden `<symbol>` sprite if misdetected | Verify sprites survive; disable if they vanish. |
| `convertShapeToPath` | on | Turns `<rect>`/`<circle>` into `<path>` — smaller but less readable/editable | Fine for shipping; disable if humans will keep editing the source. |
| `removeUnknownsAndDefaults` | on | Can strip attributes some renderers/tools rely on | Usually safe; check if a custom toolchain reads custom attrs. |

## Precision

`floatPrecision` (global) and per-plugin precision control coordinate rounding. `2` decimals is imperceptible on screen and meaningfully smaller. Go to `3` only for large-canvas or print artwork where sub-pixel curve fidelity is visible. Going below `2` starts to visibly distort curves.

## Verifying an optimization is lossless

Size dropped is not proof rendering is unchanged. Quick checks:

1. **Confirm the `viewBox` survived:** `grep viewBox output.svg` — if it's gone and the SVG had no intended fixed size, scaling is broken.
2. **Confirm referenced ids survived:** if the file uses `<use href="#x">`, `url(#grad)`, `clip-path="url(#c)"`, or `aria-labelledby`, grep that each id still exists.
3. **Diff the render, not the text:** open both in a browser side by side (or render to PNG at the same size and compare) — the markup will differ wildly even when pixels are identical, so never diff the SVG source to judge correctness.
4. **Re-check accessibility:** `<title>`/`<desc>`/`role` still present on meaningful graphics.

## When NOT to optimize

- **Source files humans keep editing.** Aggressive optimization (shape→path, merged paths, stripped ids) trades editability for bytes. Keep a readable source and optimize only on build/export.
- **SVGs with author-meaningful structure** — named layers/ids a design tool or JS relies on. Disable `cleanupIds` and `removeUnknownsAndDefaults`, or skip optimization.
