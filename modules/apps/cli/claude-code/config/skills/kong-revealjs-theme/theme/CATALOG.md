# Layout catalog

Every layout, its fields, and a copy-paste `deck.js` example. Pick the layout whose
purpose matches the slide's intent. Required fields are marked; everything else is
optional and can be left out.

Conventions used everywhere:
- `*word*` in any text renders that word neon green.
- `\n` in a heading forces a line break.

Fields available on **every** layout: `image` (see README), `noFooter: true`,
`footerNotice: "..."`.

---

## title: opening slide

Fields: `title` (req), `eyebrow`, `subtitle`, `date`, `speaker`, `variant: "cobrand"`,
and for cobrand: `position`, `photo`, `cobrand` (logo path).

```js
{ layout: "title", eyebrow: "*Kong* Konnect", title: "Platform Review",
  subtitle: "The Unified API and AI Platform", date: "JAN 2026", speaker: "Speaker Name" }
```
```js
{ layout: "title", variant: "cobrand", title: "Joint Business Review",
  cobrand: "assets/partner-logo.png", photo: "assets/speaker.jpg",
  speaker: "Speaker Name", position: "VP, Platform", date: "JAN 2026" }
```

## agenda: section overview

Fields: `heading` (req), `items` (req, array), `eyebrow` (default `AGENDA`).

```js
{ layout: "agenda", heading: "January '26",
  items: ["Where we are", "What changed", "What's next", "Open questions"] }
```

## divider: between-section punctuation

Fields: `statement` (req), `eyebrow`.

```js
{ layout: "divider", eyebrow: "Section title",
  statement: "Write a bold statement about what the next section will *communicate.*" }
```

## section-statement: claim with supporting body

Fields: `statement` (req), `eyebrow`, `body`, `cobrand` (logo path).

```js
{ layout: "section-statement", eyebrow: "Our mission",
  statement: "Write a bold statement about what the company wants to *achieve.*",
  body: "Explain how a partnership makes this real and why it is worth pursuing." }
```

## content: title + bullets or body

Fields: `title` (req), `eyebrow`, and either `bullets` (array) or `body` (string).

```js
{ layout: "content", eyebrow: "The challenge", title: "Fragmentation drives *AI failure*",
  bullets: ["First supporting point.", "Second point.", "Third point."] }
```

## big-stat: bullets anchored by one huge number

Fields: `title` (req), `stat` (req, `{ value, label }`), `eyebrow`, `bullets` (array).

```js
{ layout: "big-stat", eyebrow: "The challenge", title: "Fragmentation drives *AI failure*",
  bullets: ["First point.", "Second point."], stat: { label: "Gravity orbit cosmos", value: "+80K" } }
```

## stats-grid: up to 6 metric cells

Fields: `title` (req), `stats` (req, array of `{ value, label, highlight? }`, max 6,
one may be `highlight: true`), `note`.

```js
{ layout: "stats-grid", title: "A secure foundation for *software* delivery",
  note: "Optional supporting line, top-right.",
  stats: [
    { value: "100,000", label: "Requests per second." },
    { value: "100TB", label: "Data per day.", highlight: true },
    { value: "99.99%", label: "Availability." },
    { value: "+80K", label: "Deployments." },
    { value: "120M", label: "API calls / month." },
    { value: "<10ms", label: "Added latency." }
  ] }
```

## value-cards: numbered value/benefit cards

Fields: `cards` (req, array of `{ title, body, n? }`), `variant: "2"` or `"3"`,
`eyebrow`, `statement`.

```js
{ layout: "value-cards", variant: "3", eyebrow: "Our mission",
  statement: "Write a statement about the core principles that guide your actions.",
  cards: [
    { title: "Add a value or belief", body: "Define this value and what it reflects." },
    { title: "Add a value or belief", body: "Examples: teamwork, innovation, focus." },
    { title: "Add a value or belief", body: "Describe how it makes you a strong partner." }
  ] }
```

## team: headshot grid

Fields: `title` (req), `members` (req, array of `{ name, role?, photo? }`),
`variant: "grid"` (default, up to 12) or `"title-left"`.

```js
{ layout: "team", variant: "grid", title: "Meet the *team*",
  members: [
    { name: "Full Name", role: "Title", photo: "assets/p1.jpg" },
    { name: "Full Name", role: "Title" }
  ] }
```

## timeline: sequenced steps

Fields: `title` (req), `steps` (req), `variant: "line"` (default) or `"cards"`.
Line steps: `{ label, body, tag? }`. Cards steps: `{ label, body }`, plus `eyebrow`.

```js
{ layout: "timeline", variant: "line", title: "How the *partnership* will work",
  steps: [
    { label: "Step or milestone", body: "Outline how it grows.", tag: "January" },
    { label: "Step or milestone", body: "Shared goals.", tag: "February" }
  ] }
```
```js
{ layout: "timeline", variant: "cards", eyebrow: "Agenda", title: "Timeline",
  steps: [
    { label: "Quarter, Year", body: "Outline the next steps." },
    { label: "Quarter, Year", body: "Deliver the plan." }
  ] }
```

## partnerships: partner cards

Fields: `title` (req), `partners` (req), `variant: "2"` (default) or `"4"`.
Partner: `{ name, when?, body?, link?, logo? }` (`logo` text shows in the 4-up circle).

```js
{ layout: "partnerships", variant: "2", title: "Our successful *partnerships*",
  partners: [
    { name: "Partnership 1", when: "Quarter, Year", body: "What you did together.", link: "Learn more" },
    { name: "Partnership 2", when: "Quarter, Year", body: "What you did together.", link: "Learn more" }
  ] }
```

## green-inverted: statement on a neon background

Fields: `statement` (req), `eyebrow`. Black text on neon green.

```js
{ layout: "green-inverted", eyebrow: "Our mission",
  statement: "Write a bold statement about what the company wants to achieve." }
```

## thank-you: closing slide

Fields: `title` (req), `tagline`, `cta`, `contact` (array of strings).

```js
{ layout: "thank-you", title: "Thank you!", tagline: "Ready for what's next?", cta: "Let's talk",
  contact: ["Kong Inc.", "contact@konghq.com", "44 Montgomery Street", "San Francisco, CA 94104", "konghq.com"] }
```

---

## Data layouts

The structure is fixed; replace the data.

## awards-grid: awards / metrics / quote mix

Fields: `statement`, `eyebrow`, `cells` (req, array). Each cell has a `type`:
`metric` `{ value, label }`, `award` `{ title, sub? }`, `quote` `{ value, link? }`,
`list` `{ title, items[] }`.

```js
{ layout: "awards-grid", eyebrow: "Section title",
  statement: "Highlight your company's growth, metrics, and *achievements.*",
  cells: [
    { type: "award", title: "Industry award", sub: "Product or campaign" },
    { type: "metric", value: "00%", label: "Market share" },
    { type: "list", title: "Certifications", items: ["ISO 27001", "SOC 2 Type II"] },
    { type: "metric", value: "#00", label: "Rank in the industry" },
    { type: "quote", value: "Quote from published media coverage", link: "Link to article" }
  ] }
```

## mixed-stats: headline + mixed stat cards (one filled green)

Fields: `title` (req), `eyebrow`, `body`, `cobrand`, `cards` (req, array of
`{ value, label?, desc?, fill? }`; `fill: true` makes one card solid green).

```js
{ layout: "mixed-stats", eyebrow: "Let's work together",
  title: "Invite your potential partner to join your *business.*",
  body: "Demonstrate the benefits through charts and statistics.",
  cards: [
    { value: "+80K", label: "Add a value", desc: "Supporting line." },
    { value: "+120M", label: "Add a value", desc: "Supporting line.", fill: true },
    { value: "<10ms", label: "Add a value", desc: "Supporting line." }
  ] }
```

## persona: customer-segment dashboard

Fields: `segment` `{ title, attributes[] }`, `needs[]`, `painPoints[]`,
`skills[]` `{ label, level }` (level 0-100), `purchasing[]` `{ label, pct }` (pct 0-100),
`eyebrow` (default `OUR CUSTOMERS`).

```js
{ layout: "persona",
  segment: { title: "Customer segment title", attributes: ["Age range: 00-00", "Location: City", "Archetype: Tech-savvy"] },
  needs: ["What does this segment want?", "What motivates them?"],
  painPoints: ["What interferes with their goals?", "What frustrates them?"],
  skills: [{ label: "Device 1", level: 80 }, { label: "Device 2", level: 45 }],
  purchasing: [{ label: "Online store", pct: 90 }, { label: "Physical store", pct: 70 }] }
```

## charts: bubble + bar comparison

Fields: `title` (req), `eyebrow`, `body`, `bubble` `{ outer{label,value}, inner{label,value}, caption? }`,
`bars[]` `{ value (number), year }`, `barsCaption`.

```js
{ layout: "charts", eyebrow: "Let's work together",
  title: "Invite your potential partner to join your *business.*",
  body: "Demonstrate the benefits through charts and statistics.",
  bubble: { outer: { label: "Projected", value: "00%" }, inner: { label: "Current", value: "00%" }, caption: "Market reach" },
  bars: [{ value: 40, year: "Year" }, { value: 100, year: "Year" }], barsCaption: "ROI" }
```

## architecture: node-and-flow diagram

Fields: `title` (req), `columns[]` `{ label?, nodes[] }`. Each node has a `kind`:
`kong` (green Kong box, optional `label`), `box` (`label`), `dollar` (a `$` circle),
`bot` (a robot tile).

```js
{ layout: "architecture", title: "Ships API and AI innovation to *market faster*",
  columns: [
    { label: "MCP Clients / AI Agents", nodes: [{ kind: "bot" }, { kind: "dollar" }, { kind: "kong", label: "AI (MCP) Gateway" }] },
    { nodes: [{ kind: "box", label: "MCP Server" }, { kind: "box", label: "MCP Server" }] },
    { nodes: [{ kind: "kong", label: "AI (LLM) Gateway" }, { kind: "kong", label: "AI (LLM) Gateway" }] },
    { nodes: [{ kind: "box", label: "API" }, { kind: "box", label: "Events" }] }
  ] }
```

## freeform-panel: branded empty canvas

Escape hatch for a one-off no named layout covers. The frame and footer come from the
theme; you supply the inner `html` (composes with the `kong-*` utility classes in
`kong.css`).

Fields: `html` (req, raw string), `title`.

```js
{ layout: "freeform-panel", title: "Custom *diagram*",
  html: "<div class='kong-card'><p>Any HTML using the theme's kong-* classes.</p></div>" }
```
