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
eyebrow: KONG
speaker: Speaker Name, Role
date: APRIL 2026
tagline: One-line description that appears under the title.
---

<!--
Cover slide. The metadata above feeds eyebrow / speaker / date / tagline
into layouts/cover.vue. Keep the title to two short lines for best fit.
-->

# Kong Slidev<br/>Brand Theme

---
layout: section
eyebrow: WHY THIS MATTERS
---

# Connect every API. Every AI agent. _Every developer._

<!--
Section divider. Wrap the accent word(s) in single underscores for italic ->
the layout colors them lime green. One bold sentence per divider.
-->

---
layout: content
title: What's in the box
eyebrow: OVERVIEW
---

- Kong-locked palette and typography (Funnel Display / Funnel Sans)
- Cover, section, content, two-cols, stats, quote, image, team, closing layouts
- Fade transitions matched to PPTX feel
- Built-in support for Slidev features: code blocks, MDX, drawings, presenter notes

<!--
Default content layout. Bullets get Kong's lime square markers automatically.
-->

---
layout: stats
title: The numbers behind the platform
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
layout: image
title: Kong Konnect dashboard
eyebrow: PRODUCT
src: /kong-globe.png
position: right
---

A single control plane for every gateway, every mesh, and every AI agent in the
fleet - whether it runs in Kubernetes, on a VM, in serverless, or at the edge.

---
layout: quote
attribution: Marco Palladino, CTO, Kong
---

> The next decade of APIs isn't human-to-service. It's agent-to-everything,
> and the connective tissue has to be governed, observable, and fast.

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

<!--
top-title-two-cols puts a single title across the top with two equal columns
below. `margin: tight` shrinks padding so dense bullets breathe better.
-->

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

<!--
Click-staged reveal: each <v-click> bullet appears on click, prior bullets
fade to 35% via .kong-fader. Combine with admonitions for callouts.
-->

---
layout: full
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
`full` layout = no chrome. Drop in a hero image (sized via object-fit cover)
and overlay annotations using v-drag-positioned components. Sticky notes
with `devOnly` show only in `slidev dev` -- they disappear from builds and
exports. Perfect for speaker reminders.
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

<!--
Inline UnoCSS grid (built into Slidev) for ad-hoc 3-column layouts.
KongQRCode renders a brand-coloured QR for follow-up links.
-->

---
layout: closing
contact: dustin@konghq.com
url: konghq.com
---

# Thank you!
