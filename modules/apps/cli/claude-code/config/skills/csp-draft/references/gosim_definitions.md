# GOSIM Framework — Rigorous Definitions & Validation Rules

The CSP Draft Generator must apply these definitions with precision. A CSP that bends these rules is not a CSP — it is a to-do list with logos on it.

---

## G — Goals

**Definition**: The single overarching strategic direction of the **executive stakeholder's department or function** — the answer to "how does my team contribute to what the company is trying to achieve?" It is one rung below the company's corporate strategy, written in the voice of the CSM's primary executive contact (Head of Platform, CTO, CISO, VP Engineering, etc.). Goals do not mention Kong, API management, or technology solutions. They describe the executive stakeholder's business ambition and accountability.

**A Goal answers**: "What is the one thing this executive's function is fundamentally trying to achieve or become over the next 12–24 months, in service of the company's broader strategy?"

**Important: The Goal is departmental, not corporate.** The company may have a mission like "Revolutionize auto insurance so every family in America has coverage." That is not the CSP Goal — it is the *context* for the Goal. The CSP Goal is what the Head of Platform or CISO says when asked: "So how does your team contribute to that?" That answer — "We need to build the most reliable, self-serve developer platform in the industry so Product can ship new insurance products faster than any competitor" — is the Goal. Objectives like "reduce build time by 15% by Q2" now connect naturally and logically to it.

**Why this matters**: If the Goal is set at the corporate level, the jump from Goal to Objective becomes too large to feel credible. A CSP that goes from "Revolutionize auto insurance for every American family" straight to "reduce build time by 15% by Q2" has a logical gap that will undermine trust in the plan. The departmental Goal is the bridge.

**How to elicit a Goal in conversation**:
The recommended technique is to come prepared with the company's public strategic direction, present it to the executive, and then ask: *"So how does your department or function contribute to this? What would you consider your overarching goal in service of this?"* Their answer is the Goal. Capture it in their language, not yours.

**Characteristics**:
- **One Goal per CSP.** This is the most important rule. If you find yourself with 2–3 Goals, you have either found sub-Goals (which should become Objectives) or the executive hasn't yet clarified their primary strategic direction. Consolidate or elevate the strongest one.
- Departmental/functional scope — owned by the executive stakeholder, not the CEO
- Directional, not time-bound (no deadlines)
- Business-language only (no tech jargon, no Kong references)
- Should connect upward to company strategy and connect downward to the Objectives below it
- Sourced from direct executive conversation — NOT from a press release or earnings call (those are useful for *company* context, not the CSP Goal itself)
- The Goal anchors the executive quote in the L1 header — they should say the same thing in two different ways

**The Three-Rung Model**:
```
Company Strategy (context — research this, don't use as the Goal)
        ↓
CSP Goal (the exec stakeholder's departmental north star — THIS is the Goal)
        ↓
Objectives (time-bound, owned, measurable — these serve the Goal)
```

**Good examples** (departmental/functional level — notice these connect clearly to Objectives below them):
- "Build the most reliable, self-serve developer platform in the industry so product teams can ship faster than any competitor" *(Head of Platform at an insurance company)*
- "Become the security and compliance foundation that enables the business to move into regulated markets without slowing Engineering down" *(CISO at a fintech)*
- "Make Engineering the competitive differentiator for the business — not a bottleneck" *(VP Engineering at a retail company)*
- "Establish the API platform as a shared capability that every business unit can build on without coming to us for every request" *(Platform Owner at a telco)*
- "Ensure our AI initiatives ship securely and compliantly without becoming a security liability" *(CISO at an enterprise)*

**Bad examples** (and why):
- ❌ "Revolutionize auto insurance so every family in America has coverage" — This is the *company* strategy, not the CSP Goal. Too high. The jump to Objectives will be unconvincing.
- ❌ "Implement API gateway consolidation" — This is a Strategy/Initiative, not a Goal
- ❌ "Achieve 99.99% API uptime" — This is a Metric, not a Goal
- ❌ "Work with Kong to improve developer productivity" — Goals never reference the vendor
- ❌ "Q1: Complete API inventory" — Goals are not time-bounded tasks
- ❌ "Digital transformation" — [CAPTURE] — too vague to be a Goal
- ❌ Multiple Goals listed — If you have more than one, consolidate. Secondary "goals" are usually Objectives in disguise.

**When the Goal IS at the corporate level (the exception)**:
Sometimes the CSM's primary contact is a C-suite executive (CEO, COO, CTO) with truly company-wide scope. In these cases, a corporate-level Goal is appropriate *if* the Objectives still connect logically to it. Use judgment — the test is always: does each Objective feel like a credible, direct contribution to this Goal? If yes, the Goal can stay at company level. If the connection feels strained, apply the "one rung down" technique regardless of title.

**When you find multiple candidate Goals**:
Choose the one that is most directly stated by the executive stakeholder in their own voice, most clearly the "why" behind the engagement, and most plausible as the owner of the Objectives below it. If two are genuinely equal, ask: "Which one is this executive personally accountable for?" That's the Goal. Move the others to Objectives if they are time-bound and measurable, or flag as [CAPTURE] if they need sharpening.

**Sourcing guidance**:
- **Best source**: Direct quote or paraphrase from the executive stakeholder in a discovery conversation, QBR, or whiteboard session
- **Good source**: Sales notes or handoff docs that capture exec-level statements
- **Context-only source**: Company press releases, earnings calls, annual reports — useful for understanding the *company* strategy that the Goal should connect upward to, but not the Goal itself
- **Flag as [VERIFY]**: If the Goal appears to be paraphrased from Kong's pitch materials rather than the customer's own language

**Hard enforcement rule — vendor names in Goals**:
If the generated or extracted Goal contains any vendor name (Kong, Apigee, MuleSoft, AWS, Azure, etc.) or any technology product name, it **must** be automatically flagged [CAPTURE] and must not appear in the final CSP. No exceptions. No exec stakeholder has "prove Kong value" or "implement Kong Gateway" as their departmental goal. A Goal containing a vendor name is either an Initiative in disguise, or it is paraphrased from Kong's pitch materials rather than the customer's voice.

When this flag triggers, output a rewrite prompt to the CSM:
> ⚠️ **Goal contains a vendor name — auto-flagged [CAPTURE]**
> The current draft says: *"[original text]"*
> This is written from Kong's perspective, not the customer's. The Goal must describe the exec's business ambition, not the technology solution.
> **Rewrite using this question**: What does [exec title] want their function to *be* or *achieve* in 12–24 months that would make this engagement irrelevant to ask about — because it already succeeded?
> **Example rewrite**: "[vendor-neutral version using exec language]"

**Gap flags**:
- [MISSING] if no departmental Goal can be found or inferred from any source
- [VERIFY] if the Goal was inferred from company-level sources (press release, earnings call) and hasn't been confirmed by the executive stakeholder in conversation
- [CAPTURE] if the Goal is vague or generic (e.g., "digital transformation," "improve security") and needs the customer to sharpen it
- [CAPTURE] if the Goal appears to be at the company/CEO level when it should be at the departmental/exec level — flag this and note that the "one rung down" technique is needed
- [CAPTURE] **automatically** if the Goal contains any vendor name, product name, or technology solution reference — see hard enforcement rule above

---

## O — Objectives

**Definition**: Time-bound, measurable, owned outcomes that operationalize the Goals. Each Objective must have a named owner (role or team), a deadline, and a measurable outcome.

**An Objective answers**: "How will we know — by when, owned by whom — that we are making progress toward this Goal?"

**Characteristics**:
- Must have: an owner (role/team), a deadline, and a measurable outcome
- One Objective can support multiple Goals
- 2–5 Objectives per CSP (more than 5 = noise)
- Written from the customer's perspective
- Technology-neutral at this level (same as Goals — no Kong mention)
- Each Objective should connect logically and directly to the Goal — if the connection feels strained, the Goal may still be at the wrong rung

**Good examples**:
- "Launch developer portal to 500 internal engineers by Q2 2025 — owned by CTO Office"
- "Reduce time-to-market for new API products from 12 weeks to 4 weeks by end of FY2025 — owned by Platform Engineering"
- "Onboard 3 external partner integrations via API by July 31 — owned by Partnerships Team"

**Bad examples** (and why):
- ❌ "Improve API performance" — No owner, no deadline, not measurable
- ❌ "Complete Kong implementation" — References vendor; not customer-owned
- ❌ "By Q3, configure Kong Mesh" — This is an Initiative, not an Objective
- ❌ "Achieve digital transformation goals" — Not measurable

**The "why meat" test — Objective vs. Strategy**:
Before accepting any candidate Objective, ask: *"But why would they do this?"* If the answer goes meaningfully beyond *"to achieve the Goal"* — if there is still a real strategic reason that needs stating — then it is a **Strategy, not an Objective**. Objectives feel inherently self-justifying at the business level. You don't need to explain why a company wants to reduce costs, ship faster, or enter new markets — the business value is obvious. The moment you can answer "why" with a substantive decision about architecture, operating model, or process, you have found a Strategy.

Examples of the test in practice:
- "Reduce API platform cost 30% by Q4" → *Why?* "To free up budget for new product investment." That's just re-stating the value. ✅ **Objective**
- "Eliminate Apigee and consolidate on a single API platform" → *Why?* "Because we've decided to centralise our API estate and standardise on one vendor to reduce operational complexity." That's a deliberate architectural/operating decision. ❌ **Strategy, not Objective** — move it there and derive the Objective from the business outcome it produces (e.g., "Reduce API infrastructure cost 40% by Q4 — owned by Platform Engineering")
- "Expand Kong to all business units" → *Why?* "Because our strategy is to establish a shared platform model." ❌ **Initiative** (contains Kong) describing a **Strategy** — split them correctly

**Hard enforcement rule — vendor and product names in Objectives**:
Objectives, like Goals, are **completely technology-neutral**. Scan every candidate Objective for vendor names (Kong, Apigee, MuleSoft, AWS, Gartner, etc.) and product/tool references. If any are present, **auto-flag [CAPTURE] immediately**.

The violation pattern is almost always one of two things:
1. **It's an Initiative in disguise** — "Establish Kong as the self-service platform" → this is what Kong *does*, not what the customer achieves. Extract the business outcome ("Enable full self-service autonomy for all stream-aligned teams by Q4") as the Objective; move Kong to Initiatives.
2. **It's a Strategy in disguise** — "Migrate all API traffic from Apigee to Kong Konnect" → this is an architectural/vendor decision. Apply the "why meat" test to find the business outcome behind it ("Reduce API infrastructure cost by eliminating Apigee licensing overhead by Sep 2026") — that's the Objective. The migration approach is the Strategy.

When this flag triggers, output this block in the Extraction Summary:
> ⚠️ **Objective contains a vendor/product name — auto-flagged [CAPTURE]**
> *Draft*: "[the Objective text as extracted]"
> *Issue*: Objectives describe business outcomes the customer achieves, not technology actions. The vendor belongs in Initiatives.
> *Rewrite prompt*: "What does [customer] gain or achieve — in pure business terms — once this is done? What is the measurable outcome for the customer's business, independent of which tool they use?"
> *Example rewrite*: "[vendor-neutral version, e.g., 'Reduce API platform operating cost X% by Sep 2026 — owned by Platform Engineering']"

**Validation checklist** (flag [MISSING] if any item is absent):
- [ ] Named owner (role or team)
- [ ] Deadline / time-bound
- [ ] Measurable outcome (number, percentage, state change, launch event)
- [ ] Passes the "why meat" test — no residual strategic rationale that belongs in Strategies
- [ ] **No vendor names, product names, or tool references** (same rule as Goals — technology-neutral at this layer)

---

## S — Strategies

**Definition**: The customer's architectural, organizational, and process decisions that govern HOW they will pursue their Objectives. Strategies are vendor-neutral — Kong does NOT appear at this layer.

**A Strategy answers**: "What deliberate choices is this customer making about how they will operate — platform model, build vs. buy, centralize vs. federate — that shape how they'll reach their Objectives?"

**Characteristics**:
- Vendor-neutral by rule — if you find yourself writing "Kong" in a Strategy, it belongs in Initiatives
- Typically 1–3 Strategies per CSP
- These reflect the customer's own technology principles or operating model decisions
- Often inferred from conversations; rarely stated explicitly in documents — require discovery

**Good examples**:
- "Federated API ownership with a central governance layer (platform team sets standards, squads own APIs)"
- "Cloud-first, microservices architecture migrating from monolithic systems over 24 months"
- "Inner-source developer platform model — internal APIs treated as products with SLAs"
- "Zero-trust network architecture with API-layer enforcement"

**Bad examples** (and why):
- ❌ "Deploy Kong Gateway across all environments" — This is an Initiative
- ❌ "Use Kong for centralized authentication" — References the vendor
- ❌ "Improve security" — Too vague to be a Strategy; not a deliberate architectural choice

**How to identify a hidden Strategy**:
If an Objective fails the "why meat" test (see Objectives section) — i.e., asking "but why?" reveals a deliberate decision about architecture, operating model, or process — extract that "why" answer and turn it into a Strategy. The business outcome that was incorrectly written as an Objective usually becomes the real Objective once the Strategy is separated out.

Example: "Eliminate Apigee and consolidate on a single API platform by Q4" fails the test because the *why* (consolidating multi-vendor estate onto a single platform) is itself a deliberate architectural choice. The correct split:
- **Strategy**: Consolidate multi-vendor API estate onto a single managed platform
- **Objective**: Reduce API infrastructure cost 40% by Q4 — owned by Platform Engineering *(the business outcome the Strategy produces)*

**Gap flags**:
- [MISSING] if no Strategies can be inferred from any source — these almost always require a discovery conversation
- [CAPTURE] if only one Strategy is present (likely incomplete)
- [CAPTURE] if a candidate Objective contains a technology/vendor decision — extract the architectural choice as a Strategy and surface the business outcome as the Objective

---

## I — Initiatives

**This is where Kong appears.** Initiatives are the specific projects, deployments, and capabilities that Kong will deliver in support of the Strategies and Objectives.

**An Initiative answers**: "What is Kong doing — specifically — to enable this customer's Strategies?"

**Characteristics**:
- Kong products/capabilities are named here
- Time-bound (associated with a delivery phase or milestone)
- Specific enough to be actionable (not "implement Kong")
- Each Initiative should trace back to at least one Strategy and one Objective
- Typically organized by phase (Now / Next / Later) or by quarter

**Good examples**:
- "Phase 1 (Q1): Deploy Kong Gateway on-prem in 3 production environments with centralized auth (OAuth2/OIDC)"
- "Phase 2 (Q2): Roll out Kong Developer Portal to 200 internal consumers with self-service documentation"
- "Phase 3 (Q3): Implement Kong Mesh for east-west service-to-service mTLS enforcement"
- "Ongoing: Kong Insomnia for API design-first governance across 4 squads"

**Bad examples** (and why):
- ❌ "Improve developer experience" — Not specific enough; should name a Kong product/capability
- ❌ "Kong Gateway deployment" — Missing phase, scope, and what capability is being leveraged
- ❌ "Enable API security" — Too vague; what product, what configuration, what scope?

---

## M — Metrics

**Definition**: The specific, quantified measurements used to track progress against Objectives and the value delivered by Initiatives. Each Metric must have a baseline, a target, an owner, and a measurement cadence.

**A Metric answers**: "How are we measuring success, what is the starting point, and who is accountable for tracking it?"

**Characteristics — EVERY Metric must have ALL FOUR**:
1. **Baseline**: Current state (even if "unknown — to be established in Q1")
2. **Target**: Specific number, percentage, or state to achieve
3. **Owner**: Who tracks and reports this metric
4. **Cadence**: How often it is reviewed (monthly, quarterly, per milestone)

**Good examples**:
- "Time-to-market for new APIs | Baseline: 12 weeks | Target: 4 weeks | Owner: Platform Engineering Lead | Cadence: Quarterly"
- "Developer portal active users | Baseline: 0 (pre-launch) | Target: 200 by Q3 | Owner: CTO Office | Cadence: Monthly"
- "Security incidents at API layer | Baseline: 3/month (last 6 months avg) | Target: 0 critical / month | Owner: CISO team | Cadence: Monthly"

**Bad examples** (and why):
- ❌ "Increase API adoption" — Not quantified, no baseline, no target, no owner
- ❌ "Customer satisfaction improved" — No number, no cadence
- ❌ "99.9% uptime" — Has a target but no baseline, no owner, no cadence

**Gap flags**:
- [MISSING] for any of the four required elements (baseline, target, owner, cadence)
- [CAPTURE] if metrics are output-focused only (e.g., only measuring Kong configuration, not business outcomes)

---

## GOSIM Tracing Rules

Each element must trace logically upward:
- Initiative → must map to at least one Strategy
- Strategy → must map to at least one Objective
- Objective → must map to at least one Goal
- Metric → must map to at least one Objective

**Additional Goal tracing rule**: The Goal must also connect upward to the customer's company-level strategy. If the CSP captures the company strategy as context (Step 1 research), the CSM should be able to articulate: "This Goal is how [exec's function] contributes to [company strategy]." If that sentence doesn't make sense, the Goal may be at the wrong rung or pointed in the wrong direction.

Flag any orphaned elements (e.g., an Initiative with no traceable Strategy/Objective, or a Metric that measures something unrelated to any Objective).

---

## Common Misplacements Cheat Sheet

| Wrong Layer | Correct Layer | Note |
|---|---|---|
| "Deploy Kong Gateway" | I (Initiative) | |
| "Achieve 99.9% uptime" | M (Metric) | |
| "API-first architecture" | S (Strategy) | |
| "Work with Kong to..." | I (Initiative) | Remove vendor reference from S/O/G |
| "Complete Kong onboarding" | I (Initiative) | |
| "Reduce TTM by Q2" | O (Objective) | |
| "Digital transformation" | G (Goal) | Flag as [CAPTURE] — too vague |
| "Become the #1 insurance provider" | G — but [CAPTURE] | This is company-level. Ask: "How does your team contribute to this?" and use that answer as the Goal instead |
| "Revolutionize [industry]" | Context only | Company strategy — not the CSP Goal. Apply the one-rung-down technique. |
| "Prove Kong value" / "Maximise Kong ROI" | G — auto-flag [CAPTURE] | **Hard rule**: any Goal with a vendor name is automatically invalid. Rewrite in exec's business language. |
| "Eliminate Apigee and consolidate on single platform by Q4" | Fails "why meat" test → split into S + O | Strategy: "Consolidate multi-vendor API estate"; Objective: "Reduce API infra cost X% by Q4 — owned by Platform Eng" |
| "Expand Kong to all business units" | S (operating model decision) + I (Kong) | The architectural choice is a Strategy; the Kong rollout is an Initiative under it |
| "4M members using the platform" | Context/scope — not an Objective | No measurable do-what-by-when; this is background scale, not an owned outcome |
| "Establish Kong as the self-service integration platform" | Auto-flag [CAPTURE] → split into O + I | O: "Enable self-service autonomy for all product teams by Q4 — owned by [role]"; I: "Kong Konnect self-service onboarding + Developer Portal" |
| "Migrate all API traffic from Apigee to Kong Konnect by Sep 2026" | Auto-flag [CAPTURE] → split into O + S + I | O: "Reduce API infra cost by eliminating Apigee licensing by Sep 2026"; S: "Consolidate multi-vendor API estate onto single managed platform"; I: "Kong Konnect Gateway migration, APIOps pipeline" |
