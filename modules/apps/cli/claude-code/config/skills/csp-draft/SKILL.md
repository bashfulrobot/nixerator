---
name: csp-draft
description: >
  Draft a Kong Customer Success Plan (CSP) from raw inputs. Use this skill whenever a CSM asks to
  create, generate, or draft a CSP — whether they're coming out of a whiteboard session with a customer,
  starting a new account onboarding, or trying to structure information from sales handoff documents
  (3 Why's, Value Pyramid, technical validation, discovery notes). Also triggers on requests like
  "turn my whiteboard into a CSP", "build a success plan for [Company]", "I have the sales notes, can
  you build the first draft?", or "help me prepare the CSP before our next QBR". The skill enforces
  the GOSIM framework rigorously, flags gaps with specific discovery questions, and outputs a Kong
  dark-theme PPTX as the final deliverable. When Salesforce and Snowflake connectors are available,
  the skill automatically enriches the CSP with account data, sales context, and Clari call transcripts.
compatibility: >
  Optional but recommended: Salesforce MCP connector (account, opportunity, and line item data) and
  Snowflake MCP connector (Clari transcript search via CSM agent, account health via sql_exec_tool).
  If connectors are unavailable the skill proceeds with manual inputs only. Requires pptxgenjs (Node.js)
  for PPTX generation.
---

# CSP Draft Generator

This skill creates a structured, rigorous first draft of a Kong Customer Success Plan. It is designed
for two scenarios: **post-whiteboard** (CSM has just run a discovery whiteboard with the customer)
and **new account onboarding** (CSM has sales handoff documents but limited direct customer input).

In both cases the output follows the same two-layer template: L1 Strategic Anchor + L2 Mutual Action
Plan. Gaps are surfaced explicitly with discovery questions so the CSM can confidently validate and
finalize the plan with the customer.

---

## Reference Files

Read these references as needed — do not load them all upfront:

- `references/gosim_definitions.md` — Rigorous definitions for all 5 GOSIM elements, with good/bad
  examples and validation rules. **Read before extracting any GOSIM content.**
- `references/value_drivers.md` — Kong's four value drivers (Reduce Cost, Strengthen Security
  Posture, Enhance DevProd & DevEx, Innovate Faster) fully mapped to the GOSIM framework: Objective
  language, current/future state signals, Required Capabilities as Strategy candidates, Kong
  capabilities as Initiative candidates, metrics defaults, and persona-specific discovery questions
  by GOSIM stage. **Read during Step 2 when identifying Objectives and during Step 3 when selecting
  gap questions.**
- `references/gap_questions.md` — Discovery questions organized by gap type, GOSIM layer, and
  persona. Read when generating the Gaps & Discovery section.
- `references/kong_capabilities.md` — Kong product portfolio, value drivers, and initiative patterns
  by customer archetype. Read when drafting Initiatives.
- `references/data_sources.md` — Salesforce SOQL queries, Snowflake/Clari query patterns,
  field→GOSIM mappings, confidence rules, and tool call budget for Step 1.5. **Read at the
  start of Step 1.5.**
- `references/csp_template.md` — The exact L1 + L2 template structure and visual conventions. Read
  before generating the PPTX.

---

## Step 0 — Collect Inputs

Before doing anything else, understand what the CSM has provided.

**Scenario A — Post-Whiteboard / Post-Discovery Call:**
The CSM has just finished a discovery or whiteboard session with the customer and has one or more of:
- A photo or screenshot of the whiteboard
- A **raw call transcript** pasted directly into the conversation ← highest-value input
- A **Clari call URL** (e.g. `https://copilot.clari.com/call/...`) to reference a specific call
- A transcript or summary of the conversation
- Their own notes from the session

**Scenario B — New Account Onboarding / First Draft:**
The CSM is building a first draft from sales handoff context and has one or more of:
- Sales handoff documents: 3 Why's, Value Pyramid, deal notes, technical validation doc
- CRM opportunity data or win summary
- The customer company name (for web research)

**Either scenario can have additional context:**
- Previous CSP version to update
- EBR/QBR notes
- Customer emails or Slack threads with strategic context
- A **Salesforce Account URL** for automated enrichment

**Transcript path detection — do this now:**
Check which of the three transcript paths applies (priority order):
- **Path A**: CSM has pasted a raw transcript → flag this, no Clari queries needed in Step 1.5
- **Path B**: CSM has provided a Clari call URL → flag this, will query that specific call in Step 1.5
- **Path C**: Neither → will run 6-month account search in Step 1.5 (requires Snowflake connector)

**If no customer name is provided, ask for it now** — you need it for web research and Snowflake queries.

**If no Salesforce Account URL is provided**, note this and proceed — you'll ask for it in Step 1.5.
The skill can run without it, but enrichment will be limited.

---

## Step 1 — Research (Web Search)

Before extracting GOSIM content, gather public context on the customer's **company-level strategy**.
This research is used as *context and preparation* — not as the source of the CSP Goal itself. The
Goal will come from the executive stakeholder's departmental interpretation of this strategy
(see Step 2 — Goals).

Search for (using the customer company name):
1. Company annual report or most recent investor letter — look for strategic priorities, CEO/CFO
   language, growth themes
2. Recent press releases (last 12 months) — product launches, partnerships, acquisitions, funding
3. CEO or CTO public statements — LinkedIn posts, conference talks, media interviews
4. Industry analyst commentary or news articles about the company's digital/technology strategy

What to extract from research:
- **Company-level strategic direction**: How does leadership describe where the company is going?
  What is the mission or strategic priority they've stated publicly? This becomes the *context* the
  CSM brings to the Goal conversation — not the Goal itself.
- **Business pressures**: What competitive or regulatory dynamics are they navigating?
- **Technology signals**: Any public references to API strategy, microservices, cloud migration, AI?
- **Executive language**: The words and phrases leadership uses publicly — useful for reflecting
  back in conversation and building the L1 header quote
- **Active value drivers**: Do any of the four Kong value drivers (Reduce Cost, Strengthen Security
  Posture, Enhance DevProd & DevEx, Innovate Faster) appear to be active based on what you find?

Record sources for the Gaps & Discovery slide (Slide 3). If web search returns nothing useful, note
this and proceed — do not fabricate.

**Important framing**: Company-level statements from this research (e.g., "Become the #1 digital
bank in Southeast Asia") are background context for the CSP. They help the CSM prepare the
"one rung down" conversation with their executive contact. They are NOT the CSP Goal unless the
CSM's primary contact is the CEO/COO with truly company-wide scope.

---

## Step 1.5 — Enrich from Salesforce & Snowflake

**Read `references/data_sources.md` now.**

This step runs data enrichment before GOSIM extraction so that Step 2 has richer inputs.
It is optional in the sense that missing connectors don't stop the skill — but run it
whenever connectors are available, because Salesforce and Clari transcripts are the
single best source of [SOURCED] GOSIM content.

**Check connectors first.** If Salesforce and/or Snowflake are unavailable, note what's
missing, skip the relevant queries, and proceed. Do not block on missing connectors.

### If Salesforce Account URL is available:

Run the 3 Salesforce queries from `references/data_sources.md` (Account → Opportunity →
Line Items). Parse the results using the Field → GOSIM Mapping table and add each field
to your working extraction with its confidence level.

Key things to surface immediately:
- `Value_Drivers__c` → which of the 4 value drivers are named? Cross-reference with
  `references/value_drivers.md` to identify active Objectives
- `XDR_Current_State_Challenges__c` → feeds Goal conversation prep
- `Champion_Name__c` → pre-fills Champion on L1
- `OpportunityLineItems` → pre-fills Initiatives with contracted products [SOURCED]
- `Metrics__c` / `Requirements_Success_Metrics__c` → seeds Metrics column [VERIFY]

Also run the Snowflake account health query — this gives usage data that enriches the
Initiatives baseline and may surface Metrics proxies.

### Transcript enrichment — apply the detected path:

**Path A (transcript pasted):** Extract GOSIM content directly from the transcript text.
Treat statements made by the customer's exec/stakeholder as [SOURCED]. Statements from
the CSM or inferred from context are [INFERRED]. Skip Clari queries entirely.

**Path B (Clari URL provided):** Query Snowflake for the specific call transcript using
the call ID extracted from the URL (see `references/data_sources.md` — Path B query).
Treat content from this call as [SOURCED].

**Path C (no transcript provided — fallback):** Run the 3 Snowflake/CSM agent queries
from `references/data_sources.md`, scoped to the last 6 months. Parse the clustered
responses and map each answer to the appropriate GOSIM layer. Treat all results as
[VERIFY] — synthesized across calls, needs CSM confirmation.

### After enrichment, compile a working extraction:

Before moving to Step 2, you should have a working set of GOSIM inputs tagged by source
and confidence:
- **[SOURCED]**: directly stated by customer in transcript or transcript call, or hard
  Salesforce data (products, champion, ACV, dates)
- **[VERIFY]**: Salesforce qualitative fields (AE-captured outcomes, challenges, metrics),
  or 6-month Clari synthesis — accurate but may need updating
- **[INFERRED]**: deduced from context, web research, or pattern-matching
- **[MISSING]**: required element with no source at all

This tagged set becomes the input to Step 2 GOSIM extraction.

---

## Step 2 — Extract GOSIM Content

**Read `references/gosim_definitions.md` now if you haven't already.**

Go through all provided inputs — documents, images, transcripts, and research findings — and extract
content for each GOSIM layer. Apply the definitions strictly.

For each extracted element, track:
- The element text
- Its source (which document, which web source, or "inferred from conversation")
- A confidence level: **Sourced** (directly stated), **Inferred** (reasonably deduced), or
  **Assumed** (best guess — needs verification)

### Extraction Rules

**Goals (G):**
- There is exactly ONE Goal per CSP. It is the north star of the executive stakeholder's
  *department or function* — the answer to "how does my team contribute to what the company is
  trying to achieve?" It sits one rung below the company's corporate strategy.
- The Goal is elicited from the executive stakeholder in conversation, not sourced from a press
  release or earnings call. Company-level statements from web research are context for the
  conversation — flag them as such, not as the Goal.
- **The "one rung down" test**: Ask yourself — does each Objective connect directly and logically
  to this Goal? If the jump from Goal to Objective feels too large (e.g., from a corporate mission
  statement to a developer productivity metric), the Goal is probably at the wrong rung. Flag it
  as [CAPTURE] with the note: "This appears to be the company-level strategy. The CSP Goal should
  be the executive stakeholder's departmental interpretation — apply the one-rung-down technique
  in the next conversation."
- **HARD RULE — vendor names in Goals**: Before finalising any Goal, scan it for vendor names
  (Kong, Apigee, MuleSoft, AWS, Gartner, etc.) and technology product names. If any are present,
  **auto-flag [CAPTURE] immediately and do not include the Goal as written in the CSP**. No
  exceptions. Output this block in the Extraction Summary:
  > ⚠️ **Goal contains a vendor name — auto-flagged [CAPTURE]**
  > *Draft*: "[the Goal text as extracted]"
  > *Why*: No executive stakeholder has "prove Kong value" or a vendor's product as their
  > departmental goal. This is either an Initiative in disguise, or language paraphrased
  > from Kong's pitch materials.
  > *Rewrite prompt*: "What does [exec title] want their function to *achieve or become* over
  > the next 12–24 months, entirely independent of which vendor they use?"
  > *Example rewrite*: [vendor-neutral version using inferred exec language, e.g., "Make the
  > API platform the enabling layer that every product team at [Company] builds on — without
  > engineering bottlenecks"]
- Prefer the executive stakeholder's own words — a direct quote or paraphrase from a discovery
  call or whiteboard session is ideal.
- The Goal and the executive quote in the L1 header should say the same thing in two different ways.
- If you find only technical requirements or corporate mission statements, flag as [MISSING] or
  [CAPTURE] respectively and include the elicitation questions from `references/gap_questions.md`.

**Objectives (O):**
- **HARD RULE — vendor and product names in Objectives**: Before any other validation, scan every
  candidate Objective for vendor names (Kong, Apigee, MuleSoft, AWS, etc.) and tool references.
  If any are present, **auto-flag [CAPTURE] immediately** — do not include the Objective as
  written. G and O are both fully technology-neutral layers. The fix is almost always one of two:
  - *Initiative in disguise*: "Establish Kong as the self-service platform" → extract the
    business outcome as the Objective ("Enable self-service autonomy for all product teams by
    Q4"), move Kong to Initiatives.
  - *Strategy + Objective conflated*: "Migrate all Apigee traffic to Kong Konnect by Sep 2026"
    → the migration approach is a Strategy; the business outcome it produces ("Reduce API
    infrastructure cost by eliminating Apigee licensing by Sep 2026") is the Objective.
  Output the same [CAPTURE] block as Goals, with a rewrite showing the vendor-neutral Objective
  and where the vendor reference actually belongs (S or I).

- **Apply the "why meat" test before classifying anything as an Objective.** For each candidate,
  ask: *"But why would they do this?"* If the answer produces a meaningful strategic reason — a
  deliberate choice about architecture, operating model, or process — then the candidate is a
  **Strategy, not an Objective**. Objectives feel self-justifying at the business level: reducing
  cost, shipping faster, entering regulated markets don't need a deeper "why" to be credible. But
  "Eliminate Apigee and consolidate on a single platform" fails the test — the "why" (simplify
  operations, reduce vendor count) is a deliberate architectural decision, which belongs in S.
  When this happens: extract the architectural decision as the Strategy; derive the business
  outcome it produces (reduce cost 40%, reach new markets by Q3) as the Objective.
- **Read `references/value_drivers.md` now.** Each Objective should map to at least one of the
  four Kong value drivers. Check every candidate Objective against the four drivers:
  1. Reduce Cost
  2. Strengthen Security Posture
  3. Enhance Developer Productivity & Developer Experience (DevProd & DevEx)
  4. Innovate Faster
- If an Objective maps clearly to a driver, use the driver's Future State / Positive Business
  Outcomes language to enrich it if the customer's own language is thin.
- If an Objective does NOT map to any driver, flag it as [CAPTURE] — it may be too vague, or it
  may be misclassified (could be a Strategy or a Goal).
- Validate the three-part test: owner + deadline + measurable outcome.
- If an element has 2 out of 3 (e.g., owner + deadline but no measurable outcome), include it and
  flag the missing element — do not discard it.
- Use `references/value_drivers.md` Metrics sections to suggest measurable outcomes when the
  customer hasn't specified any.

**Strategies (S):**
- Extract architectural, organizational, or process decisions that are vendor-neutral.
- Cross-reference with the **Required Capabilities** sections in `references/value_drivers.md` —
  these are common Strategy candidates for each value driver.
- If documents only contain Kong-specific content (all Initiatives), flag Strategies as [MISSING]
  and note they require a discovery conversation.
- Do not force Kong products into Strategies — this is the most common CSP error.

**Initiatives (I):**
- Kong products appear here. Cross-reference with the **Kong Capabilities** sections in
  `references/value_drivers.md` and the full product detail in `references/kong_capabilities.md`
  to suggest relevant capabilities if source documents are thin.
- Map each Initiative to a phase (Now / Next / Later or Q1 / Q2 / Q3).
- Trace each Initiative to its parent Strategy/Objective — flag orphaned Initiatives.

**Metrics (M):**
- Validate all four required elements: baseline, target, owner, cadence.
- If no Metrics are provided, use the **Metrics** section in `references/value_drivers.md` for
  the active value driver(s) to suggest starting points — flag them as [VERIFY].
- Missing baseline is common — flag it as [MISSING] and note "to be established in Phase 1 if
  no current-state data exists."
- If only technical metrics exist (e.g., deployment count, plugin configurations), flag the absence
  of business outcome metrics and include a discovery question.

---

## Step 3 — Apply Gap Flags

After extraction, review every element for gaps. Apply these three flags:

- **[MISSING]** — A required element is completely absent and cannot be inferred from any source
- **[VERIFY]** — An element exists but needs the customer to confirm it (inferred or sourced from
  a secondary document like a sales note or press release, not a direct customer statement)
- **[CAPTURE]** — An element exists but is too vague or generic to be useful as written
  (e.g., "digital transformation", "improve developer productivity"), OR a Goal that appears to be
  at the corporate level when it should be at the departmental level

**Read `references/gap_questions.md`** and select 2–3 discovery questions for each flagged element.

When selecting questions:
- For Goal gaps: use the "one rung down" elicitation technique from the Goals section
- For Objective gaps: first check whether the driver is known, then select persona-specific
  questions from Part 2 of `references/gap_questions.md`
- Customize all questions to the specific customer context — reference the company name and the
  specific gap. Never present generic questions verbatim.

---

## Step 4 — Present the Extraction Summary (DO THIS BEFORE GENERATING PPTX)

Before generating the PPTX, show the CSM what you extracted and what gaps exist. This is the most
important step — getting CSM confirmation ensures the final PPTX reflects the right plan.

Present in this format:

```
## CSP Draft — Extraction Summary: [Customer Name]

### Sources Used
- [List each source: document names, web research URLs, whiteboard/transcript]
- Salesforce: [Account URL — or "not connected"]
- Clari transcripts: [Path A: pasted transcript / Path B: {call URL} / Path C: 6-month search — {N} calls found / "Snowflake not connected"]

### Enrichment Summary
| Layer | Pre-filled from Salesforce | Pre-filled from Clari | Still [MISSING] |
|---|---|---|---|
| G | [e.g. current state from XDR_Current_State_Challenges__c] | [e.g. exec language from QBR call] | [e.g. departmental goal — needs exec conversation] |
| O | [e.g. Value_Drivers__c: Reduce Cost, Innovate Faster] | [e.g. "reduce build time" mentioned on 3/12 call] | [e.g. owners and deadlines for all objectives] |
| S | [e.g. Decision_Criteria__c] | [e.g. federated model discussed on 2/28 call] | [e.g. no vendor-neutral strategy confirmed] |
| I | [e.g. Konnect Gateway Services, API Requests — contracted] | [e.g. AI Gateway discussed as expansion] | [e.g. phase/timeline for expansion products] |
| M | [e.g. Metrics__c field] | [e.g. "50% reduction in TTM" mentioned] | [e.g. baselines for all metrics] |

### Company Strategy (context — not the CSP Goal)
- [Company-level strategic direction surfaced from web research, with source]
- Note: This is the context for the Goal conversation, not the Goal itself. The CSP Goal is the
  executive stakeholder's departmental interpretation of this direction.

### Goal Conversation Prep
This is the ready-to-use opening for the CSM's next exec conversation. Generate this from the
company strategy research above — fill in the actual strategic direction found, the source, and
a natural follow-on question. Example format:

"I was reading [source — e.g., your 2024 annual report / a recent press release / your CEO's
LinkedIn post] and noticed that [Company] is focused on [specific strategic direction in their
language]. Is that a fair characterization of where the business is headed?

So — how does your team contribute to that? What would you consider your overarching goal in
helping [Company] get there?"

If web research returned nothing useful, note that here and provide a fallback opener:
"Before we get into the specifics — help me understand what you're ultimately trying to achieve
in your role over the next year or two. What does a win look like for your team?"

### Vendor-Name Check (mandatory — complete before showing GOSIM extraction)

Before presenting any GOSIM content to the CSM, run this scan and include the result in the summary. G, O, and S must be fully vendor- and product-neutral. Kong product names, competitor names (Mashery, Apigee, MuleSoft, AWS, Azure, Gartner, etc.), and technology tool names are only permitted in Initiatives (I).

For each G, O, and S element, output one line:

```
VENDOR-NAME SCAN
─────────────────────────────────────────────────────────────────────
G:   [PASS] / [FLAG: "{offending term}" — rewrite required]
O1:  [PASS] / [FLAG: "{offending term}" — rewrite required]
O2:  [PASS] / [FLAG: "{offending term}" — rewrite required]
O3:  [PASS] / [FLAG: "{offending term}" — rewrite required]
S1:  [PASS] / [FLAG: "{offending term}" — rewrite required]
S2:  [PASS] / [FLAG: "{offending term}" — rewrite required]
─────────────────────────────────────────────────────────────────────
```

For every FLAG, immediately below the scan block output a rewrite:
> ⚠️ **[Layer] contains a vendor/product name — must be rewritten before confirming**
> *As written*: "[original text]"
> *Problem*: [one sentence — e.g., "The migration approach belongs in Initiatives; the business outcome it produces belongs in Objectives."]
> *Suggested rewrite*: "[vendor-neutral version]"
> *Where the vendor reference actually belongs*: [S or I — with example placement]

Do not present the GOSIM extraction below until all FLAGs have suggested rewrites. If there are no flags, include the scan block with all PASS results — this confirms the check was run, not skipped.

### GOSIM Extraction

**GOAL** (the executive stakeholder's departmental north star — this becomes the slide header)
- [Goal statement] (Source: [source], Confidence: Sourced/Inferred/Assumed)
- Note: If this was sourced from company-level materials rather than a direct exec conversation,
  flag as [VERIFY] and include the one-rung-down elicitation questions.

**OBJECTIVES** (each should map to a Kong value driver)
- [Obj 1] Value Driver: [driver] | Owner: [X] | Deadline: [X] | Measure: [X] (Source: ...)
- [Obj 2] [VERIFY] — Owner not explicitly stated. Assumed: [role]. Confirm with customer.
- [Obj 3] [CAPTURE] — Does not map to a known value driver. Needs sharpening.

**STRATEGIES**
- [Strat 1] (Source: ...)
- [MISSING] No vendor-neutral architectural strategy found. Discovery question: [question]

**INITIATIVES**
- Phase 1: [Initiative] — maps to Strategy: [X], Objective: [X]
- [VERIFY] Capability assumed based on document context — confirm scope with customer

**METRICS**
- [Metric] | Baseline: [X or MISSING] | Target: [X] | Owner: [X] | Cadence: [X]

### Gaps Summary
| Layer | Gap | Type | Discovery Question |
|-------|-----|------|--------------------|
| Goal | Sourced from press release, not exec conversation | [VERIFY] | "So how does your team contribute to [company direction]? What's your overarching goal in helping [Company] get there?" |
| Objectives | Missing owner on Obj 2 | [MISSING] | "Who in your org has this in their OKRs?" |
| Strategies | No vendor-neutral strategies found | [MISSING] | "How are you thinking about API ownership across teams?" |

### Active Value Drivers
- [Driver 1]: [evidence]
- [Driver 2]: [evidence]
- [VERIFY if uncertain]

### Overall Confidence: [High / Medium / Low]
[One sentence explanation]

---
Does this look right? Fix anything that's off, confirm what's correct, and I'll generate the PPTX.
```

Wait for the CSM to respond. Do not generate the PPTX until they confirm or correct.

**What to do with their response:**
- If they correct elements: update your extraction, re-check against GOSIM definitions
- If they add new information: incorporate it and note reduced gap count
- If they say "looks good" / "go ahead": proceed to Step 5
- If they have major corrections: offer to show the updated extraction before generating

---

## Step 4.5 — Pre-Generation Validation Gate (mandatory — runs after CSM confirms, before PPTX)

Even after the CSM confirms the extraction summary, run this gate before calling any PPTX generation code. This catches cases where the CSM confirmed without fixing a flagged issue, or where a vendor name was introduced in the confirmation reply.

**Re-scan all G, O, and S content as it will appear in the PPTX** — using the confirmed/updated text, not the original extraction. Check for:

1. **Vendor or product names in G, O, or S** — Kong, Mashery, Apigee, MuleSoft, AWS, Azure, Boomi, Gartner, Salesforce, or any other named vendor or product
2. **Initiatives disguised as Objectives** — any O that contains an action verb (migrate, deploy, implement, configure, retire, roll out) rather than a business outcome
3. **Corporate-level Goal** — any G that reads like a company mission statement rather than a departmental north star

If any check fails, **block generation** and output:

```
⛔ GENERATION BLOCKED — validation failed

The following must be resolved before I can generate the PPTX:

[For each failure:]
  Layer [X]: "[offending text]"
  Issue: [specific problem in one sentence]
  Required fix: [vendor-neutral rewrite or reclassification]

Reply with the corrected version and I'll re-run the gate and proceed.
```

If all checks pass, output a single line — `✅ Validation passed — generating PPTX` — then proceed immediately to Step 5 with no further confirmation needed.

---

## Step 5 — Generate the PPTX

**Read `references/csp_template.md`** for the exact visual specification.

Generate a 3-slide PPTX using pptxgenjs (Node.js). Run with:
```
NODE_PATH=/usr/local/lib/node_modules_global/lib/node_modules node <script>.js
```

**Color palette** (from the template reference — use these hex values without `#`):
- BG: `000F06`
- LIME: `CCFF00`
- BAY: `B7BDB5`
- WHITE: `FFFFFF`
- CARD_BG: `001508`
- DARK_HD: `1A2E1A`

**Slide 1 — L1 Strategic Anchor:**

Typography: **Funnel Sans** throughout. Set all text elements with `fontFace: "Funnel Sans"`. This is the Kong primary brand font — do not fall back to any other font.

Layout: **Objective Swimlanes (Option C)**. The body of this slide is organised as horizontal swimlane bands — one band per Objective. Each band contains the Objective statement prominently at the top, with Strategy, Initiatives, and Metric nested inside the same band below it. This makes the O→S→I→M relationship explicit and scannable.

Structure:
1. **Header section** (top ~20% of slide — keep it compact): dark band (#000F06).
   - Left column (~60% width): "GOAL" micro-label (8pt, BAY, uppercase, letter-spaced) directly
     above the goal statement. Goal statement in **white, 13pt**, aligned hard left with minimal
     left padding (≤8px from slide edge) — this text should feel like it owns the left side of
     the slide, not be indented to the centre. Executive quote directly below in BAY italic 11pt,
     also hard left. Do not centre-align any header text.
   - Right column (~40% width): customer name in lime 16pt bold, "Customer Success Plan · [year]"
     in BAY 9pt beneath it, right-aligned to the slide edge.
   - Vertical padding inside the header band: 10px top, 10px bottom — tight. The header should
     feel like a bold masthead, not a spacious hero section.
2. **Objective swimlanes** (body, ~72% of slide — gains the space from the tighter header): one swimlane band per Objective, arranged vertically
   - Each band has a left-edge lime accent bar (2px wide, full band height) to visually group the row
   - **Objective statement** across the full width in white 11pt, with "OBJECTIVE" label in 8pt lime above it
   - Below the Objective: a 3-column sub-row containing:
     - **STRATEGY** (muted bay label + bay text, ~30% width)
     - **INITIATIVES** (white label + white text listing 2–3 initiatives with phase tags, ~40% width)
     - **METRIC** (green-tinted label + light green text showing baseline → target and cadence, ~30% width)
   - Thin 1px separator line between swimlane bands
3. **Footer** (bottom ~10%): Customer name | CSP period | Champion: [name] | CSM: [name]

Gap flags: Elements with [VERIFY] shown in BAY (#B7BDB5); elements with [MISSING] shown in BAY italic with a "—" placeholder and the flag inline. Never leave a lane empty — always include the flag so the CSM knows it needs filling.

Swimlane limit: Maximum 3 Objective swimlanes on one slide. If 4+ Objectives exist, prioritise the 3 with the most complete O→S→I→M chains and note the others in a "Pending Discovery" callout below the footer.

**Slide 2 — L2 Mutual Action Plan:**
- Table with sections: Now / Next / Later
- Columns: **Obj | Initiative/Milestone | Owner | Due Date | Status | Notes**
  - **Obj** column: narrow (~28px), contains a small lime-on-dark pill tag — "O1", "O2", "O3" —
    indicating which Objective from Slide 1 this action serves. If a row serves multiple
    Objectives, stack them ("O1 O2"). This is the only column that uses the lime accent colour;
    it acts as a visual thread tying the MAP back to Slide 1 without taking meaningful space.
  - Every row must have an Obj tag. If an action can't be traced to an Objective, flag it in
    Notes as "[VERIFY — no clear Objective owner]" and default to the closest match.
- Status uses color-coded badges: lime (Complete), white (In Progress), bay (Not Started),
  red-adjacent (At Risk)
- 4–8 rows per section; rows populated from confirmed Initiatives in the correct phase

**Slide 3 — Gap & Discovery Summary:**
- Header: "CSP Draft — Working Document | [Customer Name] | [Date]"
- Section 1: Sources Used (including company strategy context from web research)
- Section 2: Gaps table (Layer | Element | Gap Type | Discovery Question)
- Section 3: Active value drivers identified
- Section 4: Confidence rating with explanation
- Footer note: "This slide is for CSM use only — not customer-facing"

**File naming**: `[CustomerName]_CSP_Draft_[YYYY-MM-DD].pptx`

**Save to**: The workspace folder the user has open.

---

## Step 6 — Supplementary Outputs (Optional)

After the PPTX, offer these two additional outputs if the CSM finds them helpful:

**Follow-up email draft**: A short email the CSM can send to the customer following the whiteboard
session, summarizing what was discussed and introducing the CSP as "a first draft of what I heard
from you." Conversational tone, 150–200 words, no jargon.

**Stakeholder prep note**: A one-paragraph internal note the CSM can share with their manager or
SE, explaining the customer situation, key gaps, and recommended next steps before the next
customer call.

---

## Important Constraints

- **Never fabricate customer content.** If information is not present in the provided documents or
  verifiable via web search, flag it as [MISSING] — never invent Goals, Objectives, or customer
  quotes. An honest gap is far more useful than a plausible-sounding fiction.

- **GOSIM rigor is non-negotiable.** If an element belongs in a different layer (e.g., "Deploy Kong
  Gateway" placed in Strategies), move it to the correct layer and explain the correction. Do not
  let misplacements through to the final PPTX.

- **The Goal must be departmental, not corporate.** If the only Goal candidate is the company's
  mission statement, flag it as [CAPTURE] and include the one-rung-down elicitation questions.
  Do not let a corporate-level Goal through to the PPTX — it will make the Objectives feel
  disconnected and undermine trust in the plan.

- **Kong does not appear in G, O, or S.** If source documents reference Kong in these layers,
  reclassify to I and note the correction.

- **The Extraction Summary (Step 4) always comes before the PPTX (Step 5).** This is not optional.
  The CSM must confirm the plan before it is committed to a slide.

- **Be specific about gaps.** "Something is missing" is not useful. Identify exactly what element,
  exactly what component, and exactly what question the CSM should ask. The CSM should be able to
  take the Gaps slide directly into a customer call.
