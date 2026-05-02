---
marp: true
theme: default
size: 16:9
paginate: true
footer: '<span class="fleft">![w:16 h:14](./assets/kong/kong-mark-green.png)AI CONNECTIVITY</span><span class="fmid">© Kong Inc.</span>'
style: |
  @import url('https://fonts.googleapis.com/css2?family=Funnel+Display:wght@700;800&family=Funnel+Sans:wght@400;500;600&display=swap');
  :root {
    --kong-accent: #CCFF00;
    --kong-bg: #000000;
    --kong-card: #0e110d;
    --kong-card-strong: #1a1d18;
    --kong-border: #1f201d;
    --kong-text: #FFFFFF;
    --kong-secondary: #AAB4BB;
    --kong-muted: #8A8F89;
  }
  section { background: var(--kong-bg); color: var(--kong-text); font-family: 'Funnel Sans', sans-serif; font-weight: 400; padding: 56px 72px 80px; position: relative; }
  section::before {
    content: ''; position: absolute; top: 18px; left: 18px; right: 18px; bottom: 56px; pointer-events: none; z-index: 0;
    background:
      linear-gradient(var(--kong-accent), var(--kong-accent)) top left / 14px 1px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) top left / 1px 14px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) top right / 14px 1px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) top right / 1px 14px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) bottom left / 14px 1px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) bottom left / 1px 14px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) bottom right / 14px 1px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) bottom right / 1px 14px no-repeat;
  }
  section > * { position: relative; z-index: 1; }
  h1 { font-family: 'Funnel Display'; font-weight: 700; font-size: 36pt; color: var(--kong-text); margin: 0 0 16px; line-height: 1.15; }
  h2 { font-family: 'Funnel Sans'; font-weight: 500; font-size: 22pt; color: var(--kong-secondary); margin: 0 0 12px; }
  h3 { font-family: 'Funnel Sans'; font-weight: 600; font-size: 9pt; color: var(--kong-accent); text-transform: uppercase; letter-spacing: 0.18em; margin: 0 0 24px; }
  h4 { font-family: 'Funnel Sans'; font-weight: 600; font-size: 14pt; margin: 12px 0 6px; color: var(--kong-text); }
  strong { color: var(--kong-accent); font-weight: 600; }
  a { color: var(--kong-accent); }
  ul, ol { font-size: 14pt; line-height: 1.65; padding-left: 1.2em; }
  li { margin-bottom: 8px; }
  li::marker { color: var(--kong-accent); }
  code { background: var(--kong-card-strong); color: var(--kong-text); padding: 1px 6px; border-radius: 3px; font-size: 0.9em; word-break: break-word; overflow-wrap: anywhere; }
  footer { left: 0; right: 0; bottom: 0; height: 38px; padding: 0 24px; background: #000; border-top: 1px solid var(--kong-accent); display: flex; align-items: center; font-family: 'Funnel Sans'; font-size: 8pt; letter-spacing: 0.18em; z-index: 2; }
  footer .fleft { color: var(--kong-accent); display: inline-flex; align-items: center; gap: 8px; flex: 0 0 auto; margin-right: 28px; font-weight: 600; }
  footer .fleft img { margin: 0; vertical-align: middle; }
  footer .fmid { color: var(--kong-secondary); flex: 1 1 auto; }
  footer .fright { color: var(--kong-secondary); flex: 0 0 auto; margin-right: 56px; }
  section::after { right: 24px; bottom: 12px; color: var(--kong-secondary); font-family: 'Funnel Sans'; font-size: 8pt; letter-spacing: 0.12em; z-index: 3; }
  section.lead { padding: 0; background: var(--kong-bg); }
  section.lead::before { content: none; }
  section.lead .cover { position: absolute; inset: 0; display: grid; grid-template-columns: 1fr 1fr; }
  section.lead .cover-left { padding: 56px 56px 96px; background: #000; display: flex; flex-direction: column; justify-content: space-between; position: relative; }
  section.lead .cover-left::before { content: ''; position: absolute; top: 32px; left: 32px; right: 32px; bottom: 80px; pointer-events: none;
    background:
      linear-gradient(var(--kong-accent), var(--kong-accent)) top left / 16px 1px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) top left / 1px 16px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) top right / 16px 1px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) top right / 1px 16px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) bottom left / 16px 1px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) bottom left / 1px 16px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) bottom right / 16px 1px no-repeat,
      linear-gradient(var(--kong-accent), var(--kong-accent)) bottom right / 1px 16px no-repeat;
  }
  section.lead .cover-right { background: url('./assets/kong/kong-blades-tall.png') center / cover no-repeat, #000; }
  section.lead .wordmark { z-index: 2; }
  section.lead .wordmark img { width: 150px; }
  section.lead .title-block { z-index: 2; }
  section.lead h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 48pt; line-height: 1.05; color: var(--kong-text); margin: 0 0 18px; }
  section.lead h2 { font-family: 'Funnel Display'; font-weight: 700; font-size: 18pt; color: var(--kong-text); margin: 0 0 6px; }
  section.lead h2 .accent { color: var(--kong-accent); }
  section.lead .subtitle { font-size: 12pt; color: var(--kong-secondary); margin: 0 0 24px; max-width: 380px; }
  section.lead .meta-row { display: flex; gap: 24px; align-items: center; font-size: 9pt; letter-spacing: 0.2em; text-transform: uppercase; }
  section.lead .meta-date { color: var(--kong-accent); font-weight: 600; }
  section.lead .meta-team { color: var(--kong-secondary); }
  section.lead-cobrand .logo-bar { display: flex; gap: 0; align-items: center; margin-bottom: 24px; }
  section.lead-cobrand .logo-bar > div { padding: 18px 28px; display: flex; align-items: center; }
  section.lead-cobrand .logo-bar .kong-cell { background: #000; }
  section.lead-cobrand .logo-bar .partner-cell { background: var(--kong-card); margin-left: 1px; color: var(--kong-text); font-family: 'Funnel Display'; font-weight: 800; font-size: 18pt; letter-spacing: 0.04em; }
  section.lead-cobrand .speaker { display: flex; align-items: center; gap: 16px; margin-top: auto; }
  section.lead-cobrand .speaker .avatar { width: 56px; height: 56px; border-radius: 50%; background: var(--kong-accent); display: flex; align-items: center; justify-content: center; font-family: 'Funnel Display'; font-weight: 800; color: #000; font-size: 18pt; }
  section.lead-cobrand .speaker .info .name { font-weight: 600; font-size: 14pt; color: var(--kong-text); }
  section.lead-cobrand .speaker .info .role { font-size: 9pt; letter-spacing: 0.18em; text-transform: uppercase; color: var(--kong-accent); margin-top: 2px; }
  section.lead-closing { padding: 0; background: var(--kong-bg); display: grid; grid-template-rows: auto 1fr; }
  section.lead-closing::before { content: none; }
  section.lead-closing .top { padding: 48px 64px 24px; display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 32px; }
  section.lead-closing .top h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 36pt; color: var(--kong-text); margin: 0; }
  section.lead-closing .top .ready h3 { color: var(--kong-accent); margin: 0 0 4px; font-size: 14pt; letter-spacing: 0; text-transform: none; }
  section.lead-closing .top .ready p { color: var(--kong-secondary); font-size: 11pt; margin: 0; }
  section.lead-closing .top .contact { font-size: 10pt; color: var(--kong-text); line-height: 1.5; }
  section.lead-closing .top .contact a { color: var(--kong-accent); }
  section.lead-closing .wordmark-mega { display: flex; align-items: center; justify-content: center; padding: 0 32px 48px; }
  section.lead-closing .wordmark-mega span { font-family: 'Funnel Display'; font-weight: 800; font-size: 360pt; line-height: 0.85; color: var(--kong-accent); letter-spacing: -0.04em; }
  section.section { padding: 0; background: var(--kong-bg); }
  section.section::before { content: none; }
  section.section .divider { position: absolute; inset: 0; background: url('./assets/kong/kong-blades-wide.png') right center / cover no-repeat, #000; }
  section.section .divider-content { position: absolute; top: 0; left: 0; right: 50%; bottom: 0; padding: 72px 72px 96px; display: flex; flex-direction: column; justify-content: center; background: linear-gradient(90deg, #000 0%, #000 70%, rgba(0,0,0,0.4) 100%); z-index: 2; }
  section.section h3 { color: var(--kong-accent); font-size: 10pt; letter-spacing: 0.2em; margin-bottom: 24px; }
  section.section h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 44pt; line-height: 1.1; max-width: 100%; }
  section.section-fullbleed { padding: 0; background: var(--kong-bg); }
  section.section-fullbleed::before { content: none; }
  section.section-fullbleed .strip-top, section.section-fullbleed .strip-bottom { position: absolute; left: 0; right: 0; height: 30%; background: url('./assets/kong/kong-blades-wide.png') center / cover no-repeat; }
  section.section-fullbleed .strip-top { top: 0; }
  section.section-fullbleed .strip-bottom { bottom: 0; transform: scaleY(-1); }
  section.section-fullbleed .body { position: absolute; left: 64px; right: 64px; top: 30%; bottom: 30%; display: flex; flex-direction: column; justify-content: center; padding: 16px 32px; background: rgba(0,0,0,0.85); }
  section.section-fullbleed h3 { color: var(--kong-accent); font-size: 10pt; letter-spacing: 0.2em; margin-bottom: 20px; }
  section.section-fullbleed h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 38pt; line-height: 1.15; }
  section.section-inverted { background: var(--kong-accent); }
  section.section-inverted::before { content: none; }
  section.section-inverted .inset { position: absolute; inset: 18% 12% 18% 8%; background: #000; padding: 48px 56px; display: flex; flex-direction: column; justify-content: center; z-index: 2; }
  section.section-inverted h3 { color: var(--kong-accent); font-size: 9pt; letter-spacing: 0.2em; margin-bottom: 18px; }
  section.section-inverted h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 30pt; line-height: 1.2; color: var(--kong-text); }
  section.agenda { padding: 0; }
  section.agenda::before { content: none; }
  section.agenda .layout { position: absolute; inset: 0; display: grid; grid-template-columns: 1fr 1.5fr; }
  section.agenda .left { padding: 64px 56px 96px; background: #000 url('./assets/kong/kong-blades-orbit.png') -40px 60% / 360px no-repeat; display: flex; flex-direction: column; justify-content: center; }
  section.agenda .left h3 { color: var(--kong-accent); font-size: 10pt; letter-spacing: 0.2em; margin-bottom: 16px; }
  section.agenda .left h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 36pt; color: var(--kong-text); }
  section.agenda .right { padding: 56px 64px 96px; display: flex; flex-direction: column; justify-content: center; }
  section.agenda-timeline { padding: 0; }
  section.agenda-timeline::before { content: none; }
  section.agenda-timeline .strip-top { position: absolute; top: 0; left: 0; right: 0; height: 28%; background: url('./assets/kong/kong-blades-wide.png') right center / cover no-repeat; }
  section.agenda-timeline .strip-bottom { position: absolute; bottom: 38px; left: 0; right: 0; height: 18%; background: url('./assets/kong/kong-blades-wide.png') left center / cover no-repeat; transform: scaleY(-1); }
  section.agenda-timeline .heading { position: absolute; top: 56px; left: 64px; z-index: 3; }
  section.agenda-timeline .heading h3 { color: var(--kong-accent); }
  section.agenda-timeline .heading h1 { color: var(--kong-text); font-family: 'Funnel Display'; font-weight: 800; }
  section.agenda-timeline .qcards { position: absolute; left: 48px; right: 48px; top: 32%; display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; z-index: 3; }
  section.agenda-timeline .qcard { background: var(--kong-card-strong); padding: 20px 22px; }
  section.agenda-timeline .qcard .n { font-family: 'Funnel Display'; font-weight: 800; font-size: 24pt; color: var(--kong-accent); line-height: 1; }
  section.agenda-timeline .qcard h4 { font-size: 13pt; margin: 12px 0 8px; }
  section.agenda-timeline .qcard p { font-size: 10pt; color: var(--kong-secondary); line-height: 1.5; }
  .agenda-grid { display: grid; grid-template-columns: 1fr; margin-top: 12px; border-top: 1px solid var(--kong-border); }
  .agenda-row { display: grid; grid-template-columns: 56px 1fr; align-items: center; padding: 14px 0; border-bottom: 1px solid var(--kong-border); }
  .agenda-row .num { font-family: 'Funnel Display'; font-weight: 800; font-size: 18pt; color: var(--kong-accent); line-height: 1; }
  .agenda-row .text { font-size: 13pt; color: var(--kong-text); font-weight: 400; }
  .accent { color: var(--kong-accent); }
  .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 32px 48px; margin-top: 24px; }
  .stats-6 { display: grid; grid-template-columns: repeat(3, 1fr); grid-template-rows: repeat(2, 1fr); gap: 28px 40px; margin-top: 24px; }
  .stat .num { font-family: 'Funnel Display'; font-weight: 800; font-size: 48pt; color: var(--kong-accent); line-height: 1; }
  .stat .label { font-size: 11pt; color: var(--kong-secondary); margin-top: 8px; max-width: 280px; line-height: 1.4; }
  .stat .body { font-size: 10pt; color: var(--kong-muted); margin-top: 6px; }
  .stat-spotlight { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0; margin-top: 24px; }
  .stat-spotlight .stat { padding: 28px 24px; background: var(--kong-card); }
  .stat-spotlight .stat.hi { background: var(--kong-accent) !important; color: #000 !important; }
  .stat-spotlight .stat.hi .num, .stat-spotlight .stat.hi .label, .stat-spotlight .stat.hi .body, .stat-spotlight .stat.hi h4, .stat-spotlight .stat.hi p, .stat-spotlight .stat.hi strong { color: #000 !important; }
  .stat-spotlight .stat .num { font-size: 44pt; }
  .steps { display: grid; grid-template-columns: repeat(3, 1fr); gap: 32px; margin-top: 24px; }
  .steps.cols-2 { grid-template-columns: 1fr 1fr; }
  .steps.cols-4 { grid-template-columns: repeat(4, 1fr); }
  .step .n { font-family: 'Funnel Display'; font-weight: 800; font-size: 36pt; color: var(--kong-accent); line-height: 1; }
  .step h4 { font-family: 'Funnel Sans'; font-weight: 600; font-size: 14pt; margin: 12px 0 6px; color: var(--kong-text); }
  .step p { font-size: 11pt; color: var(--kong-secondary); line-height: 1.5; }
  .timeline-numbered { margin-top: 36px; position: relative; }
  .timeline-numbered .track { display: grid; grid-template-columns: repeat(var(--n, 5), 1fr); align-items: center; position: relative; }
  .timeline-numbered .track::before { content: ''; position: absolute; left: 6%; right: 6%; top: 50%; height: 0; border-top: 1.5px dashed var(--kong-accent); }
  .timeline-numbered .node { width: 48px; height: 48px; border-radius: 50%; border: 1.5px solid var(--kong-accent); display: flex; align-items: center; justify-content: center; font-family: 'Funnel Display'; font-weight: 800; color: var(--kong-accent); font-size: 18pt; background: #000; margin: 0 auto; position: relative; z-index: 1; }
  .timeline-numbered .node.active { background: var(--kong-accent); color: #000; }
  .timeline-numbered .body { display: grid; grid-template-columns: repeat(var(--n, 5), 1fr); gap: 16px; margin-top: 24px; padding: 24px 0; border-top: 1px solid var(--kong-border); border-bottom: 1px solid var(--kong-border); }
  .timeline-numbered .body .step h5 { font-size: 12pt; color: var(--kong-accent); font-family: 'Funnel Sans'; font-weight: 600; margin: 0 0 4px; }
  .timeline-numbered .body .step p { font-size: 10pt; color: var(--kong-secondary); line-height: 1.5; }
  .timeline-numbered .labels { display: grid; grid-template-columns: repeat(var(--n, 5), 1fr); margin-top: 14px; gap: 16px; }
  .timeline-numbered .labels .label { font-size: 9pt; letter-spacing: 0.18em; text-transform: uppercase; color: var(--kong-accent); font-weight: 600; }
  .timeline-numbered .labels .label.pill { background: var(--kong-accent); color: #000; padding: 4px 16px; border-radius: 999px; display: inline-block; justify-self: start; }
  .timeline { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-top: 28px; }
  .ms .label { font-family: 'Funnel Sans'; font-weight: 600; font-size: 8pt; color: var(--kong-accent); text-transform: uppercase; letter-spacing: 0.14em; margin-bottom: 8px; }
  .ms h5 { font-family: 'Funnel Sans'; font-weight: 600; font-size: 12pt; margin: 0 0 6px; color: var(--kong-text); }
  .ms p { font-size: 10pt; color: var(--kong-secondary); line-height: 1.5; }
  .card { background: var(--kong-card); border: 1px solid var(--kong-border); border-radius: 4px; padding: 20px 24px; }
  .card p, .card li { color: var(--kong-text); }
  .card strong { color: var(--kong-accent); }
  .two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
  .team-grid { display: grid; gap: 1px; background: var(--kong-border); margin-top: 20px; }
  .team-grid.cols-3 { grid-template-columns: repeat(3, 1fr); }
  .team-grid.cols-6 { grid-template-columns: repeat(6, 1fr); }
  .team-cell { background: var(--kong-card); padding: 18px; display: flex; flex-direction: column; justify-content: flex-end; min-height: 140px; }
  .team-cell .avatar { width: 52px; height: 52px; border-radius: 50%; background: var(--kong-accent); margin-bottom: 12px; display: flex; align-items: center; justify-content: center; font-family: 'Funnel Display'; font-weight: 800; color: #000; font-size: 16pt; }
  .team-cell .name { font-family: 'Funnel Display'; font-weight: 700; font-size: 13pt; color: var(--kong-accent); margin: 0; }
  .team-cell .title { font-size: 10pt; color: var(--kong-secondary); margin: 4px 0 0; }
  .partner-cards { display: grid; grid-template-columns: repeat(var(--n, 4), 1fr); gap: 18px; margin-top: 24px; }
  .partner-cards .pcard { background: var(--kong-card-strong); padding: 22px 22px 26px; border-radius: 2px; }
  .partner-cards .pcard .logo { width: 80px; height: 28px; border: 1px solid var(--kong-border); border-radius: 999px; display: flex; align-items: center; justify-content: center; font-size: 8pt; color: var(--kong-secondary); letter-spacing: 0.14em; margin-bottom: 16px; }
  .partner-cards .pcard h4 { font-family: 'Funnel Display'; font-weight: 700; font-size: 16pt; color: var(--kong-accent); margin: 0 0 4px; }
  .partner-cards .pcard .meta { font-size: 10pt; color: var(--kong-text); font-weight: 600; margin: 0 0 12px; }
  .partner-cards .pcard p { font-size: 10pt; color: var(--kong-secondary); line-height: 1.5; margin: 0 0 16px; }
  .partner-cards .pcard .cta { display: inline-flex; align-items: center; gap: 8px; padding: 8px 18px; background: var(--kong-accent); color: #000; font-weight: 600; font-size: 10pt; border-radius: 999px; text-decoration: none; }
  .label-statement { display: grid; grid-template-columns: 1.4fr 1fr; gap: 48px; }
  .label-statement .left h3 { color: var(--kong-accent); }
  .label-statement .left h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 32pt; line-height: 1.15; }
  .label-statement .left ul { margin-top: 18px; padding-left: 0; list-style: none; }
  .label-statement .left ul li { position: relative; padding-left: 26px; font-size: 12pt; color: var(--kong-secondary); margin-bottom: 8px; line-height: 1.5; }
  .label-statement .left ul li::before { content: ''; position: absolute; left: 0; top: 8px; width: 10px; height: 10px; background: var(--kong-accent); }
  .label-statement .left ul li::marker { content: none; }
  .label-statement .right { padding-left: 16px; border-left: 1px solid var(--kong-accent); }
  .label-statement .right p { font-size: 11pt; color: var(--kong-secondary); line-height: 1.6; }
  .split-image { display: grid; grid-template-columns: 1fr 1fr; gap: 32px; align-items: center; margin-top: 16px; }
  .split-image .media { background: var(--kong-card-strong); height: 360px; display: flex; align-items: center; justify-content: center; color: var(--kong-muted); font-size: 10pt; }
  .split-image .media.blade { background: url('./assets/kong/kong-blades-tall.png') center / cover no-repeat; }
  table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 12pt; background: transparent; }
  thead, tbody, tr { background: transparent !important; }
  thead tr { background: rgba(204, 255, 0, 0.10) !important; }
  tbody tr:nth-child(even) { background: rgba(204, 255, 0, 0.04) !important; }
  th { text-align: left; font-family: 'Funnel Sans'; font-weight: 600; font-size: 9pt; color: var(--kong-accent); text-transform: uppercase; letter-spacing: 0.14em; padding: 12px; border-bottom: 2px solid var(--kong-accent); background: transparent; }
  td { padding: 10px 12px; border-bottom: 1px solid var(--kong-border); color: var(--kong-secondary); background: transparent; }
  tbody tr td:first-child { color: var(--kong-text); font-weight: 500; }
---

<!-- _class: lead -->
<!-- _paginate: false -->

<div class="cover">
  <div class="cover-left">
    <div class="wordmark">

![](./assets/kong/kong-logo-full-green.png)

</div>
    <div class="title-block">

# The Unified API and AI Platform

## <span class="accent">Kong</span> Konnect

<p class="subtitle">Customer technical review for the platform team</p>

<div class="meta-row">
  <div class="meta-date">April 2026</div>
  <div class="meta-team">Customer Success</div>
</div>

</div>
  </div>
  <div class="cover-right"></div>
</div>

---

<!-- _class: lead lead-cobrand -->
<!-- _paginate: false -->

<div class="cover">
  <div class="cover-left">
    <div class="logo-bar">
      <div class="kong-cell">

![w:90](./assets/kong/kong-logo-full-green.png)

</div>
      <div class="partner-cell">GSK</div>
    </div>

# Co-branded review

<div class="speaker">
  <div class="avatar">DK</div>
  <div class="info">
    <div class="name">Speaker Name</div>
    <div class="role">Position</div>
  </div>
</div>

  </div>
  <div class="cover-right"></div>
</div>

---

<!-- _class: agenda -->

<div class="layout">
  <div class="left">

### Agenda

# January '26

</div>
  <div class="right">
    <div class="agenda-grid">
      <div class="agenda-row"><div class="num">1</div><div class="text">Where you are now — current API & AI estate</div></div>
      <div class="agenda-row"><div class="num">2</div><div class="text">What's changed since last review</div></div>
      <div class="agenda-row"><div class="num">3</div><div class="text">Three areas of focus for the next quarter</div></div>
      <div class="agenda-row"><div class="num">4</div><div class="text">Roadmap alignment & joint commitments</div></div>
    </div>
  </div>
</div>

---

<!-- _class: section -->
<!-- _footer: '' -->
<!-- _paginate: false -->

<div class="divider"></div>
<div class="divider-content">

### Section 01

# A secure foundation for software <span class="accent">development</span>

</div>

---

<!-- _class: section-fullbleed -->
<!-- _footer: '' -->
<!-- _paginate: false -->

<div class="strip-top"></div>
<div class="strip-bottom"></div>
<div class="body">

### Section title

# Write a bold, compelling statement about what the next section will <span class="accent">communicate.</span>

</div>

---

<!-- _class: section-inverted -->
<!-- _footer: '' -->
<!-- _paginate: false -->

<div class="inset">

### Our mission

# Write a bold, compelling statement about what the company wants to achieve.

</div>

---

### Scale today

# A secure foundation for <span class="accent">software</span> development and deployment

<div class="stats-6">
  <div class="stat"><div class="num">100,000</div><div class="label">Active developers across business units</div></div>
  <div class="stat"><div class="num">100TB</div><div class="label">Telemetry processed per month</div></div>
  <div class="stat"><div class="num">99.99%</div><div class="label">Control-plane availability YTD</div></div>
  <div class="stat"><div class="num">+80K</div><div class="label">Routes governed by central policy</div></div>
  <div class="stat"><div class="num">120M</div><div class="label">Daily API requests at peak</div></div>
  <div class="stat"><div class="num"><10ms</div><div class="label">P99 added latency at the gateway</div></div>
</div>

---

### Let's work together

# Invite your potential <span class="accent">partner</span> to join your business

<div class="stat-spotlight">
  <div class="stat"><div class="num">+80K</div><div class="label">Routes governed by central policy</div></div>
  <div class="stat hi"><div class="num">+120M</div><h4>Daily API requests</h4><p class="body">Peak across the federated estate</p></div>
  <div class="stat"><div class="num"><10ms</div><div class="label">P99 added latency at the gateway</div></div>
</div>

---

### Our recommendation

# Three phases to value

<div class="steps">
  <div class="step"><div class="n">1</div><h4>Discover</h4><p>Inventory every API and LLM call across the estate. Surface duplicate endpoints and shadow IT.</p></div>
  <div class="step"><div class="n">2</div><h4>Govern</h4><p>Land a single Kong control plane. Apply auth, rate limits, schema validation, and AI-safety policies.</p></div>
  <div class="step"><div class="n">3</div><h4>Operate</h4><p>Wire telemetry into your observability stack. Iterate on policy in production with feature flags.</p></div>
</div>

---

# How the partnership will work

<div class="timeline-numbered" style="--n: 5;">
  <div class="track">
    <div class="node active">1</div>
    <div class="node">2</div>
    <div class="node">3</div>
    <div class="node">4</div>
    <div class="node">5</div>
  </div>
  <div class="body">
    <div class="step"><h5>Step or milestone</h5><p>Outline how the partnership will grow and develop in the coming months.</p></div>
    <div class="step"><h5>Step or milestone</h5><p>Include details such as shared goals or deadlines.</p></div>
    <div class="step"><h5>Step or milestone</h5><p>Add another example. Manage check-ins and reviews.</p></div>
    <div class="step"><h5>Step or milestone</h5><p>Discuss joint initiatives, projects, or product launches.</p></div>
    <div class="step"><h5>Step or milestone</h5><p>Add as many steps as you need. Duplicate this slide if more.</p></div>
  </div>
  <div class="labels">
    <div class="label pill">January</div>
    <div class="label">February</div>
    <div class="label">March</div>
    <div class="label">April</div>
    <div class="label">May</div>
  </div>
</div>

---

<!-- _class: agenda-timeline -->

<div class="strip-top"></div>
<div class="strip-bottom"></div>
<div class="heading">

### Agenda

# Timeline

</div>
<div class="qcards">
  <div class="qcard"><div class="n">1</div><h4>Quarter, Year</h4><p>Outline the next steps of the partnership plan.</p></div>
  <div class="qcard"><div class="n">2</div><h4>Quarter, Year</h4><p>Set a deadline for drafting an agreement.</p></div>
  <div class="qcard"><div class="n">3</div><h4>Quarter, Year</h4><p>Deliver the implementation plan.</p></div>
  <div class="qcard"><div class="n">4</div><h4>Quarter, Year</h4><p>Allocate resources and decide on channels.</p></div>
</div>

---

# Meet the <span class="accent">team</span>

<div class="team-grid cols-3">
  <div class="team-cell"><div class="avatar">DK</div><p class="name">Full Name</p><p class="title">Title</p></div>
  <div class="team-cell"><div class="avatar">JS</div><p class="name">Full Name</p><p class="title">Title</p></div>
  <div class="team-cell"><div class="avatar">MR</div><p class="name">Full Name</p><p class="title">Title</p></div>
  <div class="team-cell"><div class="avatar">AC</div><p class="name">Full Name</p><p class="title">Title</p></div>
  <div class="team-cell"><div class="avatar">TL</div><p class="name">Full Name</p><p class="title">Title</p></div>
  <div class="team-cell"><div class="avatar">EP</div><p class="name">Full Name</p><p class="title">Title</p></div>
</div>

---

# Our successful <span class="accent">partnerships</span>

<div class="partner-cards" style="--n: 4;">
  <div class="pcard">
    <div class="logo">LOGO</div>
    <h4>Partnership 1</h4>
    <p class="meta">Quarter, Year</p>
    <p>Introduce one of your current partners. Mention their industry or sector and what you accomplished together.</p>
    <a class="cta" href="#">Learn more →</a>
  </div>
  <div class="pcard">
    <div class="logo">LOGO</div>
    <h4>Partnership 2</h4>
    <p class="meta">Quarter, Year</p>
    <p>Introduce one of your current partners. Mention their industry or sector and what you accomplished together.</p>
    <a class="cta" href="#">Learn more →</a>
  </div>
  <div class="pcard">
    <div class="logo">LOGO</div>
    <h4>Partnership 3</h4>
    <p class="meta">Quarter, Year</p>
    <p>Introduce one of your current partners. Mention their industry or sector and what you accomplished together.</p>
    <a class="cta" href="#">Learn more →</a>
  </div>
  <div class="pcard">
    <div class="logo">LOGO</div>
    <h4>Partnership 4</h4>
    <p class="meta">Quarter, Year</p>
    <p>Introduce one of your current partners. Mention their industry or sector and what you accomplished together.</p>
    <a class="cta" href="#">Learn more →</a>
  </div>
</div>

---

<div class="label-statement">
  <div class="left">

### The challenge

# Fragmentation drives <span class="accent">AI failure</span>

<ul>
<li>Multiple gateways for REST, gRPC, GraphQL, and now LLM traffic</li>
<li>No unified policy plane for security and compliance</li>
<li>Vendor lock-in by accident — every LLM integrated app-by-app</li>
</ul>

  </div>
  <div class="right">
    <p>Explain how a partnership would help make this goal a reality and why it's worth pursuing together. Think about how your potential partner can contribute.</p>
  </div>
</div>

---

### What we do

# Architecture at <span class="accent">a glance</span>

<div class="split-image">
  <div class="media blade"></div>
  <div>

A single Kong control plane fronts every API and LLM call in the estate. Plugins enforce auth, rate limits, AI-safety policies, and PII redaction at the edge — not in app code.

Telemetry flows to Prometheus and Datadog with no per-app wiring required.

</div>
</div>

---

# Joint roadmap — what we're committing to

<div class="timeline">
  <div class="ms"><div class="label">Q2 · Apr</div><h5>Discovery complete</h5><p>Full inventory of APIs and LLM endpoints, signed off by platform.</p></div>
  <div class="ms"><div class="label">Q2 · May</div><h5>Pilot in staging</h5><p>Two services migrated behind the Kong AI Gateway.</p></div>
  <div class="ms"><div class="label">Q2 · Jun</div><h5>Production cutover</h5><p>Pilot services live with full observability.</p></div>
  <div class="ms"><div class="label">Q3 · Jul</div><h5>Policy plane GA</h5><p>Centralised AI-safety, PII, and rate-limit policies.</p></div>
</div>

---

### Comparison

# Where Kong differs from incumbents

| Capability | Kong Konnect | Apigee | MuleSoft | AWS API Gateway |
|---|---|---|---|---|
| Hybrid CP / DP deployment | Native | Limited | Add-on | No |
| AI / LLM gateway in same plane | Yes | Roadmap | No | Bedrock-only |
| Plugin extensibility | Lua / Go / JS | JS only | DataWeave | Lambda |
| Multi-cloud + on-prem DPs | Yes | GCP-leaning | Hybrid runtime | AWS only |
| Open-source core | Yes | No | No | No |

---

<!-- _class: lead-closing -->
<!-- _paginate: false -->
<!-- _footer: '' -->

<div class="top">
  <h1>Thank you!</h1>
  <div class="ready">

### Ready for what's next?

<p>Let's talk</p>

</div>
  <div class="contact">
Kong Inc.<br>
<a href="mailto:contact@konghq.com">contact@konghq.com</a><br>
44 Montgomery Street<br>
San Francisco, CA 9410, USA<br><br>
<a href="https://konghq.com">Konghq.com</a>
  </div>
</div>
<div class="wordmark-mega"><span>Kong</span></div>
