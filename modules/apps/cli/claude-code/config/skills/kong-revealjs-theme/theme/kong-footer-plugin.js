/**
 * Kong Footer Plugin for Reveal.js 4+
 *
 * Injects the Kong footer bar into every slide that does not have
 * the data-no-footer attribute set.
 *
 * Usage — include the script, then pass KongFooter in the plugins array:
 *
 *   <script src="kong-footer-plugin.js"></script>
 *   <script>
 *     Reveal.initialize({ plugins: [ KongFooter ] });
 *   </script>
 *
 * Config (optional) — pass via the top-level Reveal config object:
 *
 *   Reveal.initialize({
 *     kong: {
 *       copyright:   '© Kong Inc.',
 *       footerCopy:  'NOT TO BE SHARED EXTERNALLY',
 *       markSrc:     'assets/images/kong-mark-footer.png',
 *     },
 *     plugins: [ KongFooter ]
 *   });
 *
 * Per-slide overrides:
 *   data-no-footer              — skip footer on this slide entirely
 *   data-footer-copy="..."      — override the right-hand disclaimer text
 */

const KongFooter = {
  id: 'kong-footer',

  init( deck ) {
    const config  = deck.getConfig();
    const kong    = config.kong || {};

    const markSrc    = kong.markSrc    || 'assets/images/kong-mark-footer.png';
    const copyright  = kong.copyright  || '© Kong Inc.';
    const footerCopy = kong.footerCopy || 'NOT TO BE SHARED EXTERNALLY';

    function injectFooter( slide ) {
      // Skip if explicitly opted out
      if ( slide.hasAttribute('data-no-footer') ) return;
      // Skip if already injected (prevent duplicates on re-render)
      if ( slide.querySelector('.kong-footer') ) return;

      const copy = slide.getAttribute('data-footer-copy') || footerCopy;

      const footer = document.createElement('div');
      footer.className = 'kong-footer';
      footer.innerHTML =
        `<img class="footer-mark" src="${markSrc}" alt="Kong" />` +
        `<span class="footer-label">AI<br>CONNECTIVITY</span>` +
        `<span class="footer-copy">${copyright}</span>` +
        `<span class="footer-right">${copy}</span>`;

      slide.appendChild( footer );
    }

    // Inject into all slides once Reveal is ready
    deck.on( 'ready', () => {
      deck.getSlides().forEach( injectFooter );
    });
  }
};
