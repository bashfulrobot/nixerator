# Kong CSP Template Structure — L1 + L2

This document defines the exact structure of a Kong Customer Success Plan. The CSP Draft Generator must follow this template. Do not invent sections, rename layers, or reorder elements.

---

## Layer 1 — Strategic Anchor

The L1 is a single slide. It is the "why" of the engagement — setting executive context and showing the full GOSIM arc at a glance.

### L1 Slide Structure

**Header band (full width, dark):**
- Customer logo (left)
- Executive quote or strategic headline (center/right)
  - Format: "[Quote or paraphrased strategic intent]" — [Role, e.g., CTO / VP Engineering]
  - If no quote is available: flag as [CAPTURE] and use a placeholder based on the customer's stated goals

**OSIM columns (4 columns, equal width, below the header):**

| OBJECTIVES | STRATEGIES | INITIATIVES | METRICS |
|-----------|-----------|-------------|---------|

The Goal is NOT a column. The Goal IS the header — the executive quote and the strategic headline at the top of the slide are the Goal. The four columns below operationalize it.

Each column contains:
- Column header (lime green on dark, uppercase)
- Bullet items written concisely — 1–2 lines per bullet
- Bullets are statements, not headings

**Footer band:**
- Customer name + Kong logo
- CSP period (e.g., "FY2025 · Q1–Q4")
- Champion name + role (left)
- Kong CSM name (right)

### L1 Design Principles
- No vendor references in G, O, S columns
- Kong appears ONLY in I (Initiatives) column
- Every element in I must trace to at least one S
- Every element in S must trace to at least one O
- Every element in M must trace to at least one O
- The exec quote sets the "north star" for the whole plan — it should be the most powerful, business-language articulation of why this matters

---

## Layer 2 — Mutual Action Plan (MAP)

The L2 is a structured action plan. It is the operational cadence layer — what is happening, when, and who owns it.

### L2 Table Structure

**Table header columns:**
1. **Initiative / Milestone** — what is being done (links back to an L1 Initiative)
2. **Owner** — who is responsible (customer role + Kong CSM)
3. **Due Date / Phase** — deadline or phase label (Q1, Q2, etc.)
4. **Status** — current state (Not Started / In Progress / Complete / At Risk / Blocked)
5. **Notes / Dependencies** — blockers, dependencies, context

### L2 Sections
Organize the MAP into phases or time periods:

- **Now (Current Quarter)** — immediate actions, onboarding steps, quick wins
- **Next (1–2 Quarters Out)** — planned deliverables, deployment milestones
- **Later (3+ Quarters / Future)** — roadmap items, expansion phases

Each phase should have 4–8 rows. Avoid MAP tables with more than 20 total rows — if there are more, it indicates scope creep or lack of prioritization.

### L2 Design Principles
- Every row must have a named owner — not just "Kong" or "Customer"
- The MAP is bilateral — both Kong and customer have rows
- Status is updated at each QBR/EBR
- Dependencies are explicit — if row 7 depends on row 3 being complete, note it
- The MAP is not a project plan — it captures strategic milestones, not every task

---

## Two-Slide Minimum, Three-Slide Preferred

A complete CSP is:
1. **Slide 1 — L1 Strategic Anchor** (always present)
2. **Slide 2 — L2 Mutual Action Plan** (always present)
3. **Slide 3 — Gap & Discovery Summary** (present in draft CSPs)
   - Lists all flagged gaps by GOSIM layer
   - Lists recommended discovery questions for the CSM to pursue
   - Lists data sources used (documents provided, web research findings)

---

## Slide 3 — Gap & Discovery Summary (Draft CSPs Only)

This slide is always included in the draft output. It is a working document for the CSM, not a customer-facing deliverable.

### Structure:

**Section 1 — Sources Used**
- Documents provided: [list each uploaded file]
- Web research: [list key sources — annual report page, press release URL, LinkedIn post, etc.]
- Whiteboard/transcript: [if provided]

**Section 2 — Gaps by GOSIM Layer**
For each layer with gaps, list:
- Element affected (e.g., "Objectives: Owner missing for Obj 2")
- Gap type: [MISSING] | [VERIFY] | [CAPTURE]
- Gap definition:
  - [MISSING] = required element is absent and cannot be inferred from any source
  - [VERIFY] = element exists but needs confirmation — it was inferred or sourced from a secondary document
  - [CAPTURE] = element exists but is too vague, generic, or needs the customer to sharpen it

**Section 3 — Recommended Discovery Questions**
- 2–3 specific questions per active gap
- Drawn from `gap_questions.md`, customized to the customer context
- Framed as "good conversation starters" not interrogation

**Section 4 — Confidence Rating**
Rate overall CSP confidence:
- **High** (70%+ of required elements present and sourced): "This draft is ready to validate with the customer. Most elements are sourced — focus on confirming Strategies and sharpening Metrics."
- **Medium** (40–70%): "This draft establishes the arc but has significant gaps. Recommend a discovery call before presenting to the customer."
- **Low** (<40%): "Insufficient inputs to build a credible CSP. Key gaps across G, O, S. Recommend a structured discovery session before drafting further."

---

## CSP Visual Conventions (Kong Dark Theme)

**Slide background**: #000F06 (Kong dark green)
**Primary text**: #FFFFFF (white)
**Accent / highlight**: #CCFF00 (electric lime)
**Secondary text / labels**: #B7BDB5 (bay/muted)
**Card backgrounds**: #001508 (slightly lighter dark)
**Column header backgrounds**: #1A2E1A
**Table dividers**: #2A3E2A

**Typography**:
- Headers: Funnel Sans Bold or fallback Arial Bold
- Body: Funnel Sans Regular or fallback Arial
- Mono/data: Roboto Mono or fallback Courier New

**Logo placement**: Bottom right corner of every slide
**Slide size**: 13.33" × 7.5" (widescreen 16:9)
