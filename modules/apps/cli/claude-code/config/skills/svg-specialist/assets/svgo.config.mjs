// SVGO config tuned for icon/UI work — safe defaults that won't break
// scalability or theming. Copy into the project root and run:
//   npx svgo --config svgo.config.mjs input.svg -o output.svg
//   npx svgo --config svgo.config.mjs -f icons/ -o icons-min/
//
// Why these choices:
// - removeViewBox is DISABLED. SVGO's default strips viewBox when
//   width/height are present, which kills CSS/responsive scaling — the
//   single most common way an "optimized" icon becomes unusable.
// - convertColors keeps currentColor intact so themeable icons stay
//   themeable.
// - cleanupIds is conservative: minifying ids would break <use href>,
//   gradient/filter/clipPath references, and aria-labelledby links.
// - floatPrecision: 2 is plenty for screen rendering; raise to 3 only
//   for very large or print artwork where sub-pixel curves matter.

export default {
  multipass: true,
  floatPrecision: 2,
  plugins: [
    {
      name: 'preset-default',
      params: {
        overrides: {
          // Preserve scalability.
          removeViewBox: false,
          // Don't rename/strip ids — they're referenced by <use>,
          // url(#...), and aria-labelledby.
          cleanupIds: false,
          // Keep <title>/<desc> for accessibility.
          removeTitle: false,
          removeDesc: false,
          // Path merging can defeat per-shape CSS targeting/animation.
          // Leave on for static art; flip to false if you animate or
          // style individual subpaths.
          mergePaths: true,
        },
      },
    },
    // Drop width/height so the container controls size (icons). Comment
    // this out for fixed-size standalone art.
    { name: 'removeDimensions' },
  ],
};
