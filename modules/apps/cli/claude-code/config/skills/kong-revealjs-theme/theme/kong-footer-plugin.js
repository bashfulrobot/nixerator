/**
 * Kong Footer Plugin for Reveal.js 4+
 *
 * Injects the Kong footer bar into every slide that does not opt out with
 * data-no-footer. Text comes from the top-level `kong` config object.
 *
 *   Reveal.initialize({
 *     kong: {
 *       markSrc:    'assets/images/kong-mark-footer.png',
 *       label:      'AI CONNECTIVITY',
 *       copyright:  '© Kong Inc.',
 *       footerCopy: 'NOT TO BE SHARED EXTERNALLY'
 *     },
 *     plugins: [ KongFooter ]
 *   });
 *
 * Per-slide overrides:
 *   data-no-footer            skip the footer on this slide
 *   data-footer-copy="..."    override the right-hand notice on this slide
 *
 * Safety: every dynamic value is HTML-escaped before insertion, so footer
 * text cannot inject markup.
 */

const KongFooter = {
  id: 'kong-footer',

  init( deck ) {
    const kong = deck.getConfig().kong || {};

    const esc = ( v ) => String( v == null ? '' : v )
      .replace( /&/g, '&amp;' ).replace( /</g, '&lt;' ).replace( />/g, '&gt;' )
      .replace( /"/g, '&quot;' );

    const markSrc    = esc( kong.markSrc    || 'assets/images/kong-mark-footer.png' );
    const label      = esc( kong.label      || 'AI CONNECTIVITY' );
    const copyright  = esc( kong.copyright  || '© Kong Inc.' );
    const footerCopy = kong.footerCopy != null ? kong.footerCopy : 'NOT TO BE SHARED EXTERNALLY';

    function injectFooter( slide ) {
      if ( slide.hasAttribute('data-no-footer') ) return;
      if ( slide.querySelector('.kong-footer') ) return;

      const copy = esc( slide.getAttribute('data-footer-copy') || footerCopy );

      const footer = document.createElement('div');
      footer.className = 'kong-footer';
      footer.insertAdjacentHTML( 'afterbegin',
        `<img class="footer-mark" src="${markSrc}" alt="Kong" />` +
        `<span class="footer-label">${label}</span>` +
        `<span class="footer-copy">${copyright}</span>` +
        `<span class="footer-right">${copy}</span>`
      );

      slide.appendChild( footer );
    }

    deck.on( 'ready', () => deck.getSlides().forEach( injectFooter ) );
  }
};

if ( typeof window !== 'undefined' ) window.KongFooter = KongFooter;
