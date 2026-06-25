/**
 * Kong reveal.js theme — render engine (hybrid model)
 *
 * Reads window.DECK (set in deck.js) and builds the slide DOM, then starts
 * reveal.js. The author writes data only; this file owns the markup.
 *
 * Safety: every author-supplied value is HTML-escaped before insertion via
 * esc()/rich(). The one exception is the `freeform-panel` layout's `html`
 * field, which is injected raw on purpose (author-trusted escape hatch).
 *
 * No build step, no modules — a plain classic script so it loads from file://.
 */
(function () {
  "use strict";

  var DECK = window.DECK || { slides: [] };
  var IMG  = 'assets/images/';

  /* ---- helpers ---------------------------------------------------------- */

  function esc(v) {
    return String(v == null ? '' : v)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  // Accent: turn *word* into a neon-green <em>, and \n into a line break.
  // Everything else is escaped.
  function rich(v) {
    if (v == null) return '';
    return String(v).split(/(\*[^*]+\*)/g).map(function (p) {
      if (p.length > 2 && p.charAt(0) === '*' && p.charAt(p.length - 1) === '*')
        return '<em>' + esc(p.slice(1, -1)) + '</em>';
      return esc(p);
    }).join('').replace(/\n/g, '<br>');
  }

  function arr(v) { return Array.isArray(v) ? v : (v == null ? [] : [v]); }
  function add(node, html) { node.insertAdjacentHTML('beforeend', html); }
  function has(v) { return v != null && v !== ''; }

  function label(eyebrow) {
    return has(eyebrow) ? '<span class="section-label">' + esc(eyebrow) + '</span>' : '';
  }

  // Optional transparent image slot (auto-hides when absent).
  function slot(image) {
    if (!image || !image.src) return '';
    var anchor = image.anchor || 'bottom-right';
    var size   = image.size   || '480px';
    var pos = {
      'right':        'right:0;top:50%;transform:translateY(-50%);',
      'bottom-right': 'right:0;bottom:0;',
      'bottom-left':  'left:0;bottom:0;',
      'left':         'left:0;top:50%;transform:translateY(-50%);',
      'center-right': 'right:6%;top:50%;transform:translateY(-50%);'
    }[anchor] || 'right:0;bottom:0;';
    var dim = size.indexOf('%') > -1 ? 'width:' + size + ';' : 'height:' + size + ';';
    var z = image.layer === 'back' ? '0' : '6';
    return '<img class="kong-slot" src="' + esc(image.src) + '" alt="' + esc(image.alt || '') +
           '" style="position:absolute;' + pos + dim + 'z-index:' + z + ';" />';
  }

  /* ---- layout renderers ------------------------------------------------- */
  /* Each returns the inner HTML for the <section>. The section class is
     `slide-<layout>`. Frame + footer are added separately.                 */

  var L = {};

  L['title'] = function (s) {
    var cobrand = s.variant === 'cobrand';
    var brand = '<div class="kong-title-brand">' +
        '<img class="kong-title-wordmark" src="' + IMG + 'kong-wordmark.png" alt="Kong" />' +
        (cobrand && has(s.cobrand)
          ? '<span class="kong-title-sep"></span><img class="kong-title-cobrand" src="' + esc(s.cobrand) + '" alt="" />'
          : '') +
      '</div>';
    var info = '<div class="kong-title-info">' +
        (has(s.eyebrow) ? '<p class="kong-title-tag">' + rich(s.eyebrow) + '</p>' : '') +
        (has(s.subtitle) ? '<p class="kong-title-sub">' + esc(s.subtitle) + '</p>' : '') +
      '</div>';
    var meta;
    if (cobrand) {
      meta = '<div class="kong-title-meta cobrand">' +
          (has(s.photo) ? '<img class="kong-title-photo" src="' + esc(s.photo) + '" alt="" />' : '') +
          '<div class="kong-title-person">' +
            '<span class="kong-meta-speaker">' + esc(s.speaker || '') + '</span>' +
            (has(s.position) ? '<span class="kong-meta-position">' + esc(s.position) + '</span>' : '') +
          '</div>' +
          (has(s.date) ? '<span class="kong-meta-date">' + esc(s.date) + '</span>' : '') +
        '</div>';
    } else {
      meta = '<div class="kong-title-meta">' +
          (has(s.date) ? '<span class="kong-meta-date">' + esc(s.date) + '</span>' : '') +
          '<span class="kong-meta-speaker">' + esc(s.speaker || '') + '</span>' +
        '</div>';
    }
    return '<img class="kong-title-bg" src="' + IMG + 'bg-rays-faded.png" alt="" aria-hidden="true" />' +
      brand +
      '<div class="kong-title-panel"><h1>' + rich(s.title) + '</h1></div>' +
      info + meta;
  };

  L['agenda'] = function (s) {
    var items = arr(s.items).map(function (it, i) {
      return '<div class="agenda-item"><span class="agenda-num">' + (i + 1) +
        '</span><span class="agenda-title">' + rich(it) + '</span></div>';
    }).join('');
    return '<div class="kong-agenda-left">' +
        label(s.eyebrow || 'AGENDA') +
        '<h2>' + rich(s.heading) + '</h2>' +
      '</div>' +
      '<div class="kong-agenda-right">' + items + '</div>';
  };

  L['divider'] = function (s) {
    return '<img class="kong-divider-bg" src="' + IMG + (s.bg || 'bg-hero-ring.png') + '" alt="" aria-hidden="true" />' +
      '<div class="kong-divider-content">' +
        label(s.eyebrow) +
        '<h2>' + rich(s.statement) + '</h2>' +
      '</div>';
  };

  L['section-statement'] = function (s) {
    return '<div class="kong-ss-main">' +
        label(s.eyebrow) +
        '<h2>' + rich(s.statement) + '</h2>' +
      '</div>' +
      '<div class="kong-ss-body">' +
        (has(s.body) ? '<p>' + esc(s.body) + '</p>' : '') +
        (has(s.cobrand) ? '<img class="kong-ss-cobrand" src="' + esc(s.cobrand) + '" alt="" />' : '') +
      '</div>';
  };

  L['content'] = function (s) {
    var head = '<div class="slide-header">' + label(s.eyebrow) +
      (has(s.title) ? '<h2>' + rich(s.title) + '</h2>' : '') + '</div>';
    var bodyHtml = '';
    if (s.bullets) {
      bodyHtml = '<ul class="kong-bullets">' +
        arr(s.bullets).map(function (b) { return '<li>' + rich(b) + '</li>'; }).join('') + '</ul>';
    } else if (has(s.body)) {
      bodyHtml = '<div class="kong-bodytext"><p>' + esc(s.body) + '</p></div>';
    }
    return head + bodyHtml;
  };

  L['big-stat'] = function (s) {
    var bullets = s.bullets ? '<ul class="kong-bullets">' +
      arr(s.bullets).map(function (b) { return '<li>' + rich(b) + '</li>'; }).join('') + '</ul>' : '';
    var st = s.stat || {};
    return '<div class="kong-bigstat-head">' + label(s.eyebrow) +
        (has(s.title) ? '<h2>' + rich(s.title) + '</h2>' : '') + '</div>' +
      bullets +
      '<div class="kong-bigstat-num">' +
        (has(st.label) ? '<span class="kong-bigstat-label">' + esc(st.label) + '</span>' : '') +
        '<span class="kong-bigstat-value">' + esc(st.value) + '</span>' +
      '</div>';
  };

  L['stats-grid'] = function (s) {
    var cells = arr(s.stats).map(function (c) {
      return '<div class="kong-stat-cell' + (c.highlight ? ' highlight' : '') + '">' +
        '<span class="kong-stat-value">' + esc(c.value) + '</span>' +
        '<p class="kong-stat-desc">' + esc(c.label) + '</p></div>';
    }).join('');
    return '<div class="kong-stats-head">' +
        (has(s.title) ? '<h2>' + rich(s.title) + '</h2>' : '') +
        (has(s.note) ? '<p class="kong-stats-note">' + esc(s.note) + '</p>' : '') +
      '</div>' +
      '<div class="kong-stats-grid">' + cells + '</div>';
  };

  L['value-cards'] = function (s) {
    var cols = (s.variant === '2' || s.variant === 2) ? 2 : 3;
    var cards = arr(s.cards).map(function (c, i) {
      return '<div class="kong-vc-card">' +
        '<span class="kong-vc-num">' + esc(has(c.n) ? c.n : (i + 1)) + '</span>' +
        '<div class="kong-vc-text">' +
          (has(c.title) ? '<h3>' + rich(c.title) + '</h3>' : '') +
          (has(c.body) ? '<p>' + esc(c.body) + '</p>' : '') +
        '</div></div>';
    }).join('');
    return '<div class="kong-vc-head">' + label(s.eyebrow) +
        (has(s.statement) ? '<h2>' + rich(s.statement) + '</h2>' : '') + '</div>' +
      '<div class="kong-vc-grid cols-' + cols + '">' + cards + '</div>';
  };

  L['team'] = function (s) {
    var titleLeft = s.variant === 'title-left';
    var cells = arr(s.members).map(function (m) {
      var photo = has(m.photo)
        ? '<div class="kong-team-photo" style="background-image:url(' + esc(m.photo) + ')"></div>'
        : '<div class="kong-team-photo empty"></div>';
      return '<div class="kong-team-cell">' + photo +
        '<div class="kong-team-meta">' +
          '<span class="kong-team-name">' + esc(m.name) + '</span>' +
          (has(m.role) ? '<span class="kong-team-role">' + esc(m.role) + '</span>' : '') +
        '</div></div>';
    }).join('');
    return '<div class="kong-team-head">' +
        (has(s.title) ? '<h2>' + rich(s.title) + '</h2>' : '') + '</div>' +
      '<div class="kong-team-grid' + (titleLeft ? ' title-left' : '') + '">' + cells + '</div>';
  };

  L['timeline'] = function (s) {
    var cards = s.variant === 'cards';
    var steps = arr(s.steps);
    if (cards) {
      var cardEls = steps.map(function (st, i) {
        return '<div class="kong-tl-card">' +
          '<span class="kong-tl-cardnum">' + esc(has(st.n) ? st.n : (i + 1)) + '</span>' +
          (has(st.label) ? '<h4>' + esc(st.label) + '</h4>' : '') +
          (has(st.body) ? '<p>' + esc(st.body) + '</p>' : '') + '</div>';
      }).join('');
      return '<img class="kong-tl-bg" src="' + IMG + 'bg-rays.png" alt="" aria-hidden="true" />' +
        '<div class="kong-tl-head">' + label(s.eyebrow || 'AGENDA') +
          (has(s.title) ? '<h2>' + rich(s.title) + '</h2>' : '') + '</div>' +
        '<div class="kong-tl-cards">' + cardEls + '</div>';
    }
    var nodes = steps.map(function (st, i) {
      return '<div class="kong-tl-node"><span class="kong-tl-circle">' + (i + 1) + '</span></div>';
    }).join('');
    var colsEl = steps.map(function (st) {
      return '<div class="kong-tl-col">' +
        (has(st.label) ? '<h4>' + esc(st.label) + '</h4>' : '') +
        (has(st.body) ? '<p>' + esc(st.body) + '</p>' : '') + '</div>';
    }).join('');
    var tags = steps.map(function (st, i) {
      return has(st.tag) ? '<span class="kong-tl-tag' + (i === 0 ? ' first' : '') + '">' + esc(st.tag) + '</span>'
                         : '<span class="kong-tl-tag empty"></span>';
    }).join('');
    return '<div class="kong-tl-head">' +
        (has(s.title) ? '<h2>' + rich(s.title) + '</h2>' : '') + '</div>' +
      '<div class="kong-tl-track">' + nodes + '</div>' +
      '<div class="kong-tl-cols">' + colsEl + '</div>' +
      '<div class="kong-tl-tags">' + tags + '</div>';
  };

  L['partnerships'] = function (s) {
    var cols = (s.variant === '4' || s.variant === 4) ? 4 : 2;
    var cards = arr(s.partners).map(function (p) {
      return '<div class="kong-pt-card">' +
        (cols === 4 ? '<span class="kong-pt-logo">' + esc(p.logo || 'LOGO') + '</span>' : '') +
        '<h3>' + rich(p.name) + '</h3>' +
        (has(p.when) ? '<p class="kong-pt-when">' + esc(p.when) + '</p>' : '') +
        (has(p.body) ? '<p class="kong-pt-body">' + esc(p.body) + '</p>' : '') +
        (has(p.link) ? '<span class="kong-pt-pill">' + esc(p.link) + ' &rsaquo;</span>' : '') +
      '</div>';
    }).join('');
    return '<div class="kong-pt-head">' +
        (has(s.title) ? '<h2>' + rich(s.title) + '</h2>' : '') + '</div>' +
      '<div class="kong-pt-grid cols-' + cols + '">' + cards + '</div>';
  };

  L['green-inverted'] = function (s) {
    return '<img class="kong-gi-bg" src="' + IMG + (s.bg || 'bg-torus.png') + '" alt="" aria-hidden="true" />' +
      '<div class="kong-gi-content">' +
        (has(s.eyebrow) ? '<span class="kong-gi-eyebrow">' + esc(s.eyebrow) + '</span>' : '') +
        '<h2>' + esc(s.statement) + '</h2>' +
      '</div>';
  };

  L['thank-you'] = function (s) {
    var contact = arr(s.contact).map(function (line) {
      return '<p>' + (typeof line === 'string' ? esc(line) : '') + '</p>';
    }).join('');
    return '<div class="kong-ty-top">' +
        '<h2 class="kong-ty-headline">' + rich(s.title || 'Thank you!') + '</h2>' +
        '<div class="kong-ty-cta">' +
          (has(s.tagline) ? '<h3>' + esc(s.tagline) + '</h3>' : '') +
          (has(s.cta) ? '<p>' + esc(s.cta) + '</p>' : '') +
        '</div>' +
        '<div class="kong-ty-contact">' + contact + '</div>' +
      '</div>' +
      '<div class="kong-ty-wordmark"><span>Kong</span></div>';
  };

  /* ---- data layouts (fixed composition, swap the data) ------------------ */

  L['awards-grid'] = function (s) {
    var cellHtml = function (c) {
      var t = c.type || 'metric';
      if (t === 'award') return '<div class="kong-aw-cell award"><span class="kong-aw-dot"></span>' +
        '<h4>' + esc(c.title) + '</h4>' + (has(c.sub) ? '<p>' + esc(c.sub) + '</p>' : '') + '</div>';
      if (t === 'quote') return '<div class="kong-aw-cell quote"><p class="q">&ldquo;' + esc(c.value) + '&rdquo;</p>' +
        (has(c.link) ? '<a>' + esc(c.link) + '</a>' : '') + '</div>';
      if (t === 'list')  return '<div class="kong-aw-cell list"><h4>' + esc(c.title) + '</h4>' +
        (c.items ? '<ul class="kong-bullets">' + arr(c.items).map(function (i) { return '<li>' + esc(i) + '</li>'; }).join('') + '</ul>' : '') + '</div>';
      return '<div class="kong-aw-cell metric"><span class="kong-stat-value">' + esc(c.value) + '</span>' +
        '<p>' + esc(c.label) + '</p></div>';
    };
    return '<div class="kong-aw-head">' + label(s.eyebrow) +
        (has(s.statement) ? '<h2>' + rich(s.statement) + '</h2>' : '') + '</div>' +
      '<div class="kong-aw-grid">' + arr(s.cells).map(cellHtml).join('') + '</div>';
  };

  L['mixed-stats'] = function (s) {
    var cards = arr(s.cards).map(function (c) {
      return '<div class="kong-mx-card' + (c.fill ? ' fill' : '') + '">' +
        '<span class="kong-stat-value">' + esc(c.value) + '</span>' +
        (has(c.label) ? '<h4>' + esc(c.label) + '</h4>' : '') +
        (has(c.desc) ? '<p>' + esc(c.desc) + '</p>' : '') + '</div>';
    }).join('');
    return '<div class="kong-mx-head">' + label(s.eyebrow) +
        (has(s.title) ? '<h2>' + rich(s.title) + '</h2>' : '') +
        (has(s.body) ? '<p class="kong-mx-body">' + esc(s.body) + '</p>' : '') +
        (has(s.cobrand) ? '<img class="kong-mx-cobrand" src="' + esc(s.cobrand) + '" alt="" />' : '') +
      '</div>' +
      '<div class="kong-mx-cards">' + cards + '</div>';
  };

  L['persona'] = function (s) {
    var seg = s.segment || {};
    var bul = function (list) {
      return '<ul class="kong-bullets">' + arr(list).map(function (i) { return '<li>' + esc(i) + '</li>'; }).join('') + '</ul>';
    };
    var bars = arr(s.skills).map(function (k) {
      return '<div class="kong-pe-bar"><span>' + esc(k.label) + '</span>' +
        '<div class="kong-pe-track"><div class="kong-pe-fill" style="width:' + esc(k.level) + '%"></div></div></div>';
    }).join('');
    var purch = arr(s.purchasing).map(function (p) {
      return '<div class="kong-pe-purchase"><span class="kong-pe-chip" style="width:' +
        Math.max(8, Math.round((p.pct || 0) / 2)) + 'px"></span>' + esc(p.label) + '</div>';
    }).join('');
    return '<div class="kong-pe-head">' + label(s.eyebrow || 'OUR CUSTOMERS') + '</div>' +
      '<div class="kong-pe-grid">' +
        '<div class="kong-pe-seg"><h3>' + esc(seg.title) + '</h3>' + bul(seg.attributes) + '</div>' +
        '<div class="kong-pe-mid">' +
          '<h4>Needs and motivations</h4>' + bul(s.needs) +
          '<h4>Pain points</h4>' + bul(s.painPoints) +
        '</div>' +
        '<div class="kong-pe-right">' +
          '<h4>Technical skills</h4>' + bars +
          '<h4>Purchasing habits</h4>' + purch +
        '</div>' +
      '</div>';
  };

  L['charts'] = function (s) {
    var bub = s.bubble || {}; var outer = bub.outer || {}; var inner = bub.inner || {};
    var maxV = arr(s.bars).reduce(function (m, b) { return Math.max(m, +b.value || 0); }, 1);
    var bars = arr(s.bars).map(function (b) {
      var h = Math.max(8, Math.round((+b.value || 0) / maxV * 100));
      return '<div class="kong-ch-bar"><span class="kong-ch-barval">' + esc(b.value) + '%</span>' +
        '<div class="kong-ch-barfill" style="height:' + h + '%"></div>' +
        '<span class="kong-ch-baryear">' + esc(b.year) + '</span></div>';
    }).join('');
    return '<div class="kong-ch-head">' + label(s.eyebrow) +
        (has(s.title) ? '<h2>' + rich(s.title) + '</h2>' : '') +
        (has(s.body) ? '<p>' + esc(s.body) + '</p>' : '') + '</div>' +
      '<div class="kong-ch-vis">' +
        '<div class="kong-ch-bubble">' +
          '<div class="kong-ch-outer"><span class="kong-ch-olabel">' + esc(outer.label) + '<br>' + esc(outer.value) + '</span>' +
            '<div class="kong-ch-inner"><span>' + esc(inner.label) + '<br>' + esc(inner.value) + '</span></div>' +
          '</div>' +
          '<span class="kong-ch-caption">' + esc(bub.caption || 'Market reach') + '</span>' +
        '</div>' +
        '<div class="kong-ch-bars">' + bars + '<span class="kong-ch-caption">' + esc(s.barsCaption || 'ROI') + '</span></div>' +
      '</div>';
  };

  L['architecture'] = function (s) {
    var nodeHtml = function (n) {
      var kind = n.kind || 'box';
      if (kind === 'kong') return '<div class="kong-ar-node kong"><img src="' + IMG + 'kong-mark.png" alt="" />' +
        (has(n.label) ? '<span>' + esc(n.label) + '</span>' : '') + '</div>';
      if (kind === 'dollar') return '<div class="kong-ar-node dollar">$</div>';
      if (kind === 'bot') return '<div class="kong-ar-node bot">&#129302;</div>';
      return '<div class="kong-ar-node box">' + esc(n.label) + '</div>';
    };
    var cols = arr(s.columns).map(function (col) {
      return '<div class="kong-ar-col">' +
        (has(col.label) ? '<span class="kong-ar-collabel">' + esc(col.label) + '</span>' : '') +
        arr(col.nodes).map(nodeHtml).join('') + '</div>';
    }).join('');
    return '<div class="kong-ar-head">' +
        (has(s.title) ? '<h2>' + rich(s.title) + '</h2>' : '') + '</div>' +
      '<div class="kong-ar-flow">' + cols + '</div>';
  };

  L['freeform-panel'] = function (s) {
    // Author-trusted raw HTML escape hatch.
    return '<div class="kong-ff">' +
      (has(s.title) ? '<div class="slide-header"><h2>' + rich(s.title) + '</h2></div>' : '') +
      (s.html || '') + '</div>';
  };

  /* ---- assembly --------------------------------------------------------- */

  function frame(invert) {
    return '<div class="kong-frame' + (invert ? ' inv' : '') + '"><i></i><i></i><i></i><i></i></div>';
  }

  function buildSlide(s) {
    var layout = s.layout || 'freeform-panel';
    var fn = L[layout] || L['freeform-panel'];
    var sec = document.createElement('section');
    sec.className = 'slide-' + layout + (s.variant ? ' v-' + s.variant : '');
    if (s.noFooter) sec.setAttribute('data-no-footer', '');
    if (has(s.footerNotice)) sec.setAttribute('data-footer-copy', s.footerNotice);
    if (s.image && s.image.src && s.image.layer !== 'back') sec.classList.add('has-img');

    add(sec, frame(layout === 'green-inverted'));
    add(sec, fn(s));
    add(sec, slot(s.image));
    return sec;
  }

  var container = document.querySelector('.reveal .slides');
  arr(DECK.slides).forEach(function (s) { container.appendChild(buildSlide(s)); });

  /* ---- start reveal ----------------------------------------------------- */

  var f = DECK.footer || {};
  var plugins = [];
  if (window.KongFooter) plugins.push(window.KongFooter);
  if (window.RevealNotes && DECK.notes !== false) plugins.push(window.RevealNotes);

  window.Reveal.initialize({
    width: 1920,
    height: 1080,
    margin: 0,
    center: false,
    hash: true,
    controls: DECK.controls === true,
    progress: DECK.progress === true,
    slideNumber: DECK.slideNumber === false ? false : 'c',
    transition: DECK.transition || 'fade',
    transitionSpeed: 'fast',
    backgroundTransition: 'fade',
    kong: {
      markSrc:    IMG + 'kong-mark-footer.png',
      label:      f.label     || 'AI CONNECTIVITY',
      copyright:  f.copyright || '© Kong Inc.',
      footerCopy: f.notice    || 'NOT TO BE SHARED EXTERNALLY'
    },
    plugins: plugins
  });
})();
