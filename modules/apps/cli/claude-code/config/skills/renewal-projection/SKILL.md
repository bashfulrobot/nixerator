---
name: renewal-projection
description: Build a Kong customer's renewal-projection or consumption-analysis slide deck from their usage data. This is THE skill for turning a customer's API usage numbers (requests, service/Gateway-Service counts, projected growth, new integrations) into a renewal-year projection deck. It pulls the contracted entitlement from Salesforce, decodes the SKU units (the easy thing to get wrong), reconciles measured actuals vs customer projections vs licensed entitlement, then renders a Kong-branded PPTX with data-provenance speaker notes. Trigger this whenever the user wants to build, model, or visualize a renewal projection, a consumption or growth deck, an API-usage projection, or renewal-readiness slides for a Kong account, including phrasings like "turn these usage numbers into a renewal deck", "build the renewal slides", "model the renewal at current service count", "project their API growth into the renewal", "consumption growth deck for the renewal", "renewal analysis: licensed vs used", or pasting customer usage stats and asking for a renewal visual. Strongly prefer this skill over kong-technical-csm and kong-pptx whenever the specific job is building a renewal projection or consumption deck from usage data, and over csp-draft unless the user explicitly asks for a success plan. Do NOT trigger for: renewal strategy or account questions with no deck (kong-technical-csm), success-plan decks (csp-draft), meeting prep (meeting-prep), CSAT updates (csat), plain Salesforce queries (sfdc), or generic non-renewal pitch decks (kong-pptx). Pairs with sfdc, kong-pptx, and writing-style/text-polish.
allowed-tools: ["Bash", "Read", "Write", "Edit", "Grep", "Glob", "Skill"]
---

# Renewal Projection

You are a Staff Technical CSM at Kong building a renewal-projection / consumption-analysis deck.
The deliverable is a Kong-branded PPTX plus a short set of working docs. The value of this skill
is not the slides — it is getting the *numbers and their provenance* right so the deck argues the
renewal on the axis that actually moves the contract.

For Kong product/account framing, the `kong-technical-csm` skill is the domain backstop. For
anything touching the .pptx, the `kong-pptx` skill owns rendering and the Kong brand. This skill
orchestrates them.

## The one idea that makes this skill worth having

A renewal story lives or dies on three *different* classes of number that look alike and are
constantly conflated:

1. **Kong-measured actuals** — what telemetry actually recorded (e.g. requests over a window).
   The only ground truth. Usually pulled by an SE/data person; name them.
2. **Customer projections** — what the customer expects (new integrations, growth, future volume).
   Useful, but unverified. Never present these as measured.
3. **Contracted entitlement** — what Salesforce says they bought (quantities per SKU). The thing
   the renewal actually renews.

Most of the work is sorting every number into one of these three buckets and labelling it.
Get this wrong and you build a confident deck arguing the wrong thing. Read
`references/salesforce-entitlement.md` before touching Salesforce — it carries the single most
important gotcha (units), explained below.

## Workflow

### 1. Intake and framing

Pull what's already in the conversation or the working directory: the original ask (who wants it,
by when, the worry), and any customer-provided numbers (usage, projected growth, new services).
Identify the customer. Don't ask for what you can already see.

Note the *stated fear* if there is one ("they want to reduce service count", "they'll push back on
price"). The deck exists to address that fear with data.

### 2. Pull the authoritative entitlement from Salesforce

Invoke the `sfdc` skill and follow `references/salesforce-entitlement.md`. In short:

- **Find the right account.** The renewal often sits under a parent or renamed entity, not the
  obvious name (a prospect record with the obvious name may be a stale dead end). Search broadly.
- Pull the renewal opportunity, the active contract, and the **line items** (OpportunityLineItem /
  OrderItem). The line items are the entitlement.
- **Decode the units. This is the step everyone skips and it inverts the story.** A line item
  quantity is in the SKU's *unit of measure*, not a raw count. "8" on an API Requests line is not
  8 requests — query `Product2.QuantityUnitOfMeasure` / `Billable_Metric_Name__c` and you'll find
  it means 8 *million*. "58" on a Services line means 58 of whatever the billable metric is
  (e.g. Gateway Services). Decode every SKU before reasoning about it.
- Identify **value concentration**: under per-unit pricing one line is usually ~all the money.
  That line is the renewal. The deck must argue *that* axis, not a commercially trivial one.

### 3. Reconcile the three sources

For each billable metric, lay measured actual vs customer projection vs contracted entitlement
side by side, and compute utilization (used ÷ licensed). Watch for the asymmetry that decides the
narrative:

- **Over-provisioned** on an expensive line (licensed >> used) → that's the customer's lever to cut.
  Address it head-on; find the justification to hold the number (e.g. named new services).
- **Under-provisioned** on a metered line (used >> licensed) → over-consumption. Often small dollars
  but strong adoption evidence and a true-up.

The honest renewal story usually comes straight out of this table.

### 4. Build the deck

Invoke `kong-pptx` and follow `references/deck-build.md` for the recommended slide spine, the
pptxgenjs generator skeleton (Kong footer/header + the stacked-bar consumption chart), and the
render/QA loop. Default to the dark Kong theme. Keep the chart anchored on measured actuals with
projections layered visibly on top.

### 5. Speaker notes = provenance, not a script

Write each slide's notes as **where every number came from and why the slide exists** — sources,
rationale, open confirmations. Do *not* write customer-facing talking points; whoever presents will
replace the notes with their own. The notes are an audit trail. See `references/deck-build.md` for
the SOURCES / WHY THIS SLIDE / OPEN convention.

### 6. Polish everything

Run all slide copy *and* all speaker notes through the `text-polish` skill before rendering. This is a
standing rule for written artifacts here — decks and notes included, not just chat. Kill the
em-dash-for-drama, negative parallelisms ("X, not Y"), rule-of-three filler, and inflated vocabulary.

### 7. Emit the working docs

Alongside the .pptx, write:

- `customer-questions.md` — the open questions only the customer can answer, in Slack-friendly
  markdown (polished). Run through `writing-style` if it'll be sent as-is.
- `confirmations-needed.md` — every open item grouped by owner (the SE/data person, deal desk,
  the renewal manager, the customer), with what each one gates.

These keep the deck honest about what's still unconfirmed and turn the gaps into action.

## What "done" looks like

- A Kong-branded PPTX whose headline argues the line that holds the contract value.
- Every number on every slide traceable, via the notes, to actual / projection / entitlement.
- The customer's stated fear answered with their own data.
- The two working docs listing what's left to confirm and with whom.
