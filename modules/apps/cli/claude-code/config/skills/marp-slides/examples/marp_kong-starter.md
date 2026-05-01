---
marp: true
theme: default
size: 16:9
paginate: true
header: '![w:36 h:32](./assets/kong/kong-mark-green.png)'
footer: 'AI CONNECTIVITY  ·  © Kong Inc.  ·  CONFIDENTIAL | NOT TO BE SHARED EXTERNALLY'
style: |
  @import url('https://fonts.googleapis.com/css2?family=Funnel+Display:wght@700;800&family=Funnel+Sans:wght@400;500;600&display=swap');
  :root {
    --kong-accent: #CCFF00;
    --kong-bg: #000000;
    --kong-card: #30352F;
    --kong-border: #1f201d;
    --kong-text: #FFFFFF;
    --kong-secondary: #AAB4BB;
    --kong-muted: #8A8F89;
  }
  section {
    background: var(--kong-bg);
    color: var(--kong-text);
    font-family: 'Funnel Sans', sans-serif;
    font-weight: 400;
    padding: 56px 72px 88px;
  }
  h1 { font-family: 'Funnel Display'; font-weight: 700; font-size: 36pt; color: var(--kong-text); margin: 0 0 16px; line-height: 1.15; }
  h2 { font-family: 'Funnel Sans'; font-weight: 500; font-size: 22pt; color: var(--kong-secondary); margin: 0 0 12px; }
  h3 { font-family: 'Funnel Sans'; font-weight: 600; font-size: 9pt; color: var(--kong-accent); text-transform: uppercase; letter-spacing: 0.18em; margin: 0 0 24px; }
  strong { color: var(--kong-accent); font-weight: 600; }
  a { color: var(--kong-accent); }
  ul, ol { font-size: 14pt; line-height: 1.65; padding-left: 1.2em; }
  li { margin-bottom: 8px; }
  li::marker { color: var(--kong-accent); }
  header { right: 56px; top: 28px; }
  footer { left: 72px; right: 72px; bottom: 28px; font-size: 7pt; color: var(--kong-muted); letter-spacing: 0.08em; }
  section::after { color: var(--kong-muted); font-size: 7pt; right: 56px; bottom: 28px; }
  section.lead { display: flex; flex-direction: column; justify-content: center; padding: 72px 96px; }
  section.lead h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 64pt; line-height: 1.05; color: var(--kong-text); }
  section.lead h2 { font-size: 22pt; color: var(--kong-secondary); }
  section.lead .meta { margin-top: auto; font-size: 10pt; color: var(--kong-muted); letter-spacing: 0.12em; text-transform: uppercase; }
  section.lead .brand { margin-top: 48px; }
  section.section { display: flex; flex-direction: column; justify-content: center; padding: 72px 96px; }
  section.section h1 { font-family: 'Funnel Display'; font-weight: 800; font-size: 56pt; line-height: 1.1; max-width: 900px; }
  .accent { color: var(--kong-accent); }
  .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 32px 48px; margin-top: 24px; }
  .stat .num { font-family: 'Funnel Display'; font-weight: 800; font-size: 56pt; color: var(--kong-accent); line-height: 1; }
  .stat .label { font-size: 11pt; color: var(--kong-secondary); margin-top: 8px; max-width: 280px; line-height: 1.4; }
  .steps { display: grid; grid-template-columns: repeat(3, 1fr); gap: 32px; margin-top: 24px; }
  .step .n { font-family: 'Funnel Display'; font-weight: 800; font-size: 36pt; color: var(--kong-accent); line-height: 1; }
  .step h4 { font-family: 'Funnel Sans'; font-weight: 600; font-size: 14pt; margin: 12px 0 6px; color: var(--kong-text); }
  .step p { font-size: 11pt; color: var(--kong-secondary); line-height: 1.5; }
  .card { background: var(--kong-card); border: 1px solid var(--kong-border); border-radius: 4px; padding: 20px 24px; }
  .two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 32px; }
  .timeline { display: grid; grid-template-columns: repeat(5, 1fr); gap: 16px; margin-top: 32px; }
  .ms .label { font-family: 'Funnel Sans'; font-weight: 600; font-size: 8pt; color: var(--kong-accent); text-transform: uppercase; letter-spacing: 0.14em; margin-bottom: 8px; }
  .ms h5 { font-family: 'Funnel Sans'; font-weight: 600; font-size: 12pt; margin: 0 0 6px; color: var(--kong-text); }
  .ms p { font-size: 10pt; color: var(--kong-secondary); line-height: 1.5; }
  table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 12pt; background: transparent; }
  thead, tbody, tr { background: transparent !important; }
  tbody tr:nth-child(even) { background: rgba(204, 255, 0, 0.04) !important; }
  th { text-align: left; font-family: 'Funnel Sans'; font-weight: 600; font-size: 9pt; color: var(--kong-accent); text-transform: uppercase; letter-spacing: 0.14em; padding: 10px 12px; border-bottom: 1px solid var(--kong-border); background: transparent; }
  td { padding: 10px 12px; border-bottom: 1px solid var(--kong-border); color: var(--kong-secondary); background: transparent; }
  tbody tr td:first-child { color: var(--kong-text); font-weight: 500; }
---

<!-- _class: lead -->
<!-- _footer: '' -->
<!-- _header: '' -->
<!-- _paginate: false -->

# The Unified API and AI Platform

## Customer technical review

<div class="brand">

![w:280](./assets/kong/kong-logo-full-green.png)

</div>

<div class="meta">APRIL 2026  ·  Dustin Krysak  ·  Staff Technical CSM</div>

---

### Agenda

# What we'll cover today

1. Where you are now — current API & AI estate
2. What's changed since last review
3. Three areas of focus for the next quarter
4. Roadmap alignment & joint commitments
5. Q&A

---

<!-- _class: section -->
<!-- _header: '' -->
<!-- _footer: '' -->
<!-- _paginate: false -->

### Section 01

# A secure foundation for software <span class="accent">development</span>

---

### Scale today

# Your platform at a glance

<div class="stats">
  <div class="stat"><div class="num">100K+</div><div class="label">Active developers across business units</div></div>
  <div class="stat"><div class="num">120M</div><div class="label">Daily API requests at peak</div></div>
  <div class="stat"><div class="num">99.99%</div><div class="label">Control-plane availability YTD</div></div>
</div>

<div class="stats">
  <div class="stat"><div class="num">+80K</div><div class="label">Routes governed by central policy</div></div>
  <div class="stat"><div class="num">100TB</div><div class="label">Telemetry processed per month</div></div>
  <div class="stat"><div class="num">&lt;10ms</div><div class="label">P99 added latency at the gateway</div></div>
</div>

---

<!-- _class: section -->
<!-- _header: '' -->
<!-- _footer: '' -->
<!-- _paginate: false -->

### Section 02

# Fragmentation drives AI <span class="accent">failure</span>

---

### The challenge

# Why most AI initiatives stall

- **Multiple gateways** for REST, gRPC, GraphQL, and now LLM traffic — each with its own auth, rate-limit, and observability story
- **No unified policy plane** — security teams cannot enforce data-loss-prevention or PII redaction across LLM and traditional API traffic
- **Vendor lock-in by accident** — every LLM provider is integrated app-by-app instead of behind a single AI Gateway abstraction
- **Operational drift** — staging configs do not match production; deck-based runbooks rot the moment the platform team rotates

---

### Our recommendation

# Three phases to value

<div class="steps">
  <div class="step">
    <div class="n">1</div>
    <h4>Discover</h4>
    <p>Inventory every API and LLM call across the estate. Surface duplicate endpoints, shadow IT, and the LLM providers your developers are quietly evaluating.</p>
  </div>
  <div class="step">
    <div class="n">2</div>
    <h4>Govern</h4>
    <p>Land a single Kong control plane. Apply auth, rate limits, schema validation, and AI-safety policies at the gateway — not in app code.</p>
  </div>
  <div class="step">
    <div class="n">3</div>
    <h4>Operate</h4>
    <p>Wire telemetry into your observability stack. Iterate on policy in production with feature flags and progressive rollout, not change-board tickets.</p>
  </div>
</div>

---

### Joint roadmap

# What we're committing to this half

<div class="timeline">
  <div class="ms">
    <div class="label">Q2 · Apr</div>
    <h5>Discovery complete</h5>
    <p>Full inventory of APIs and LLM endpoints, signed off by platform.</p>
  </div>
  <div class="ms">
    <div class="label">Q2 · May</div>
    <h5>Pilot in staging</h5>
    <p>Two services migrated behind the Kong AI Gateway in a non-prod region.</p>
  </div>
  <div class="ms">
    <div class="label">Q2 · Jun</div>
    <h5>Production cutover</h5>
    <p>Pilot services live in production with full observability.</p>
  </div>
  <div class="ms">
    <div class="label">Q3 · Jul</div>
    <h5>Policy plane GA</h5>
    <p>Centralised AI-safety, PII, and rate-limit policies across all teams.</p>
  </div>
  <div class="ms">
    <div class="label">Q3 · Aug</div>
    <h5>QBR review</h5>
    <p>Measure: P99 latency, policy violations caught, team adoption.</p>
  </div>
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
| Open-source core | Yes (OSS Kong Gateway) | No | No | No |

---

### What we need from you

# To stay on track

<div class="two-col">

<div class="card">

**Platform team**

Two engineers, ~30% allocation through end of Q2. Owners for: control-plane install, OIDC integration, and the first three service migrations.

</div>

<div class="card">

**Security & compliance**

Sign-off on the AI-safety policy bundle by **15 May**. Includes PII redaction defaults, prompt-injection detection, and audit-log retention.

</div>

</div>

---

<!-- _class: lead -->
<!-- _footer: '' -->
<!-- _header: '' -->
<!-- _paginate: false -->

# Thank you

## Ready for what's next?

<div class="brand">

![w:240](./assets/kong/kong-logo-full-green.png)

</div>

<div class="meta">dustin.krysak@konghq.com  ·  Konghq.com  ·  San Francisco, CA</div>
