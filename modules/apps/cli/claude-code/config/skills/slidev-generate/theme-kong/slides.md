---
theme: default
title: Deck Title
info: |
  ## Kong Slidev deck
  Themed after the Kong PPTX brand template.
class: text-white
drawings:
  persist: false
transition: fade
mdc: true
hideInToc: true
fonts:
  sans: 'Funnel Sans'
  serif: 'Funnel Display'
  mono: 'JetBrains Mono'
defaults:
  transition: fade
# Deck-level chrome configs (read by KongChrome via $slidev.configs)
kong_category: AI CONNECTIVITY
kong_copyright: 'Kong Inc. 2026'
kong_external: 'NOT TO BE SHARED EXTERNALLY'
# Cover layout props
layout: cover
product: Konnect
tagline: One platform for every API, every AI agent, every developer.
date: APRIL 2026
speaker: Speaker Name, Role
---

# Kong Slidev<br/>Brand Theme

<!--
Cover slide. Title slot accepts <h1>; product/tagline render in the lower
inset; date appears as a lime pill, speaker beside it. Phyllotaxis hero
fills the right side via the kong-blades-tall asset.
-->

---
layout: section
eyebrow: WHY THIS MATTERS
---

# Connect every API. Every AI agent. _Every developer._

<!--
Section divider. Wrap the accent word(s) in single underscores for italic,
or `**bold**` for lime emphasis. Phyllotaxis bands top + bottom, statement
in the middle band.
-->

---
layout: agenda
title: Today
eyebrow: AGENDA
date: APR 30
items:
  - { title: 'Where APIs are headed', note: 'AI agents change the connective tissue' }
  - { title: 'The Konnect platform', note: 'Single control plane, every runtime' }
  - { title: 'Customer outcomes', note: 'Numbers, stories, recognition' }
  - { title: 'Get started', note: 'Resources and next steps' }
---

---
layout: content
title: What's in the box
eyebrow: OVERVIEW
---

- Kong-locked palette and typography (Funnel Display / Funnel Sans)
- 17 layouts mirroring the bundled PPTX brand template
- Phyllotaxis brand assets and corner registration crosses
- Built-in support for Slidev features: code blocks, MDX, drawings, presenter notes

<!--
Default content layout. Bullets get Kong's lime square markers automatically.
-->

---
layout: mission
eyebrow: MISSION
statement: Make every connection between **services**, **AI agents**, and **developers** secure, observable, and fast.
body: We build the connective tissue that lets enterprises ship faster without trading away governance, performance, or trust.
---

---
layout: stats
title: The numbers behind **the platform**
eyebrow: AT A GLANCE
items:
  - { value: '700B+', label: 'API Calls / Month', note: 'Across customer infrastructure.' }
  - { value: '60K+', label: 'Community Stars' }
  - { value: '100+', label: 'Plugins' }
  - { value: '32', label: 'Industries Served' }
  - { value: '#1', label: 'Open-source API Gateway' }
  - { value: '99.999%', label: 'SLA on Konnect' }
footer: Trusted by enterprises across every regulated and ungoverned vertical.
---

---
layout: stats-trio
title: The platform in **three numbers**
eyebrow: SCALE
intro: Customer-reported telemetry across the fleet during the trailing twelve months.
items:
  - { value: '700B+', label: 'API calls / month', note: 'Plane-of-record traffic' }
  - { value: '99.999%', label: 'SLA', note: 'Konnect cloud control plane' }
  - { value: '<5ms', label: 'P99 latency', note: 'Per-request gateway overhead' }
footer: Source -- aggregated customer telemetry, FY26.
---

---
layout: hero-stat
title: One number that **says it all**
eyebrow: SCALE
intro: Across our customer base, the Kong fleet handles more than two-thirds of a trillion API calls in a typical month.
label: API calls processed
value: 700B+
note: Trailing 12 months, customer-reported.
---

---
layout: numbered-values
title: Three principles
eyebrow: HOW WE BUILD
intro: Every product decision rolls up to one of these three.
items:
  - { title: 'Open by default', body: 'Every commercial product has an open-source core that customers can run, fork, and audit.' }
  - { title: 'Performance first', body: 'Latency budgets and throughput targets are non-negotiable. Features that regress them do not ship.' }
  - { title: 'Connective tissue', body: 'We do not own the endpoints. We make every endpoint reachable, governable, and observable.' }
---

---
layout: achievements-mosaic
title: Where the industry has placed us
eyebrow: RECOGNITION
award:
  label: 'Gartner MQ'
  name: 'Leader, API Management 2025'
  note: '7th consecutive year.'
share:
  label: 'Open-source share'
  value: '74%'
  note: 'Of public GitHub gateway forks reference Kong.'
quote:
  body: 'Kong is the gateway we benchmark every other gateway against.'
  attribution: 'CTO, Fortune 100 financial services'
---

---
layout: partnership-stats
title: What partnership with Kong **looks like**
eyebrow: WORKING TOGETHER
intro: Customers who deploy with our solutions team see consistent gains in time-to-value and operating cost.
items:
  - { value: '4x', label: 'Faster onboarding', note: 'Average time from POC to production' }
  - { value: '63%', label: 'Lower TCO', note: 'vs. self-built gateway alternatives' }
footer: Source -- Forrester TEI commissioned study, 2025.
---

---
layout: persona
title: Platform Engineer
name: 'Priya, Staff Platform Engineer'
eyebrow: WHO BUYS THIS
image: '/kong-globe.png'
quote: 'I do not want to be the bottleneck. I want every team to ship safely without asking me first.'
demographics:
  - '8-15 years experience'
  - 'Reports to VP Engineering or CTO'
  - 'Owns 2-5 platform engineers'
needs:
  - 'Self-service onboarding for app teams'
  - 'Centralized policy and observability'
  - 'Multi-runtime, multi-cloud parity'
channels:
  - 'GitHub, KubeCon, Hacker News'
  - 'Internal slack platform-eng channel'
  - 'Direct from peers at other companies'
---

---
layout: partnership-cards
title: Four ways customers engage
eyebrow: ENGAGEMENT MODELS
intro: Every customer chooses the model that fits their delivery cadence and operating model.
items:
  - { label: 'Self-serve', metric: '14d', title: 'Konnect free tier', body: 'Sign up, install a data plane, route real traffic in two weeks.' }
  - { label: 'Standard', metric: '60d', title: 'Konnect Plus', body: 'Production support, multi-region, audit-ready logging.' }
  - { label: 'Enterprise', metric: '90d', title: 'Konnect Enterprise', body: 'Dedicated CSM, custom SLAs, plugin co-development.' }
  - { label: 'Strategic', metric: 'Custom', title: 'Joint roadmap', body: 'Quarterly executive review and forward-looking feature alignment.' }
---

---
layout: timeline
title: A typical rollout
eyebrow: HOW IT GOES
intro: Phased rollouts let app teams adopt at their own pace while the platform team stays in control.
items:
  - { label: 'Week 0', title: 'Discovery', body: 'Map current gateways and traffic.' }
  - { label: 'Week 2', title: 'Pilot', body: 'Two services behind Konnect.' }
  - { label: 'Week 6', title: 'Production', body: 'Critical path traffic migrated.' }
  - { label: 'Week 12', title: 'Self-service', body: 'App teams onboarding solo.' }
  - { label: 'Quarter 2', title: 'AI plane', body: 'Agent-aware policy enforcement.' }
---

---
layout: comparison-stats
title: Before vs. after **on a single chart**
eyebrow: THE DIFFERENCE
intro: Customers who consolidate gateway sprawl onto Konnect see immediate operational and financial gains.
bullets:
  - 'Time from change-merge to production cut by more than half'
  - 'Audit and compliance evidence collected automatically'
  - 'P99 latency improved on most workloads, never regressed'
bars:
  - { label: 'Latency p99', value: 92, display: '−38%', highlight: true }
  - { label: 'TTM', value: 76, display: '−54%', highlight: true }
  - { label: 'Headcount', value: 41, display: '−22%' }
  - { label: 'Cost', value: 88, display: '−63%', highlight: true }
footer: Source -- Forrester TEI commissioned study, 2025.
---

---
layout: two-cols
title: Two-column comparison
eyebrow: BEFORE / AFTER
---

::left::

#### Before

- Manual API onboarding
- No central observability
- Disjointed authn / authz
- Tribal knowledge runbooks

::right::

#### After

- Self-service Dev Portal
- Unified Konnect telemetry
- Single OIDC / mTLS plane
- AI agents with policy guardrails

<!--
The custom two-cols layout uses Slidev's named slots: ::left:: and ::right::
markers split content. Use #### headings inside slots for column titles.
-->

---
layout: top-title-two-cols
title: Same control plane, different runtimes
eyebrow: ARCHITECTURE
margin: tight
---

:: left ::

#### Konnect (cloud)

- Managed control plane
- SLA-backed (99.999%)
- Auto-upgrades, no downtime
- Region-aware data planes

:: right ::

#### Self-managed (on-prem)

- Full control over CP + DP
- Air-gap supported
- Customer-managed upgrades
- Customer-supplied SLOs

---
layout: image
title: Kong Konnect dashboard
eyebrow: PRODUCT
src: /kong-globe.png
caption: KONNECT, JUNE 2026
position: right
---

A single control plane for every gateway, every mesh, and every AI agent in the
fleet — whether it runs in Kubernetes, on a VM, in serverless, or at the edge.

---
layout: quote
attribution: Marco Palladino
role: CTO, Kong
---

> The next decade of APIs isn't human-to-service. It's agent-to-everything, and
> the connective tissue has to be **governed, observable, and fast**.

---
layout: team
title: Meet the team
people:
  - { name: 'Jane Doe', title: 'VP Engineering' }
  - { name: 'John Smith', title: 'Director, Platform' }
  - { name: 'Alex Kim', title: 'Staff Engineer' }
  - { name: 'Robin Chen', title: 'PM, Konnect' }
  - { name: 'Sam Patel', title: 'Solutions Architect' }
  - { name: 'Lee Park', title: 'CSM' }
---

---
layout: content
title: Layered request flow
eyebrow: WALKTHROUGH
---

<div class="kong-fader">

<v-clicks>

- **Edge** — TLS terminates at the gateway
- **Auth** — OIDC / mTLS / API key plugin chain
- **Policy** — rate-limit, ACL, request transform
- **Routing** — service / route match, retries
- **Upstream** — load-balance, health-check, observe

</v-clicks>

</div>

<KongAdmonition type="perf">
Plugin order matters. Auth → rate-limit → transform is the canonical chain;
swapping rate-limit ahead of auth lets unauthenticated traffic burn budget.
</KongAdmonition>

---
layout: full
bleed: true
hideFooter: true
---

<img src="/kong-globe.png" alt="Topology" />

<KongBox label="Auth boundary" v-drag="[140, 140, 360, 200]" />

<KongStickyNote
  title="Aside"
  width="260px"
  v-drag="[820, 200, 260, 'auto']"
>
Anything inside the lime box runs on customer infrastructure.
The control plane lives elsewhere.
</KongStickyNote>

<KongStickyNote
  title="To do"
  width="260px"
  devOnly
  v-drag="[820, 460, 260, 'auto']"
>
Replace this hero image with the customer's actual topology before the call.
</KongStickyNote>

<KongArrow :x1="500" :y1="240" :x2="780" :y2="240" :width="3" />

<!--
`full` with bleed=true drops the inset frame and fills the entire canvas.
Useful for hero topology diagrams overlaid with v-drag annotations. Sticky
notes with `devOnly` show only in `slidev dev` -- they disappear from
builds and exports. Perfect for speaker reminders.
-->

---
layout: content
title: Follow-up
eyebrow: NEXT STEPS
margin: tight
---

<div class="grid grid-cols-3 gap-8 items-start">

<div>

#### What you'll get

- Session recording
- Architecture runbook
- Sample plugin chain
- Office hours invite

</div>

<div>

#### Recommended reading

- Konnect quickstart
- decK declarative config
- Plugin development guide

</div>

<div>

<KongQRCode value="https://docs.konghq.com" caption="Docs" :size="180" />

</div>

</div>

---
layout: closing
cta: "Ready for what's next?"
ctaSub: "Let's talk"
contact: dustin@konghq.com
url: konghq.com
---
