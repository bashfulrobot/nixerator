---
name: kong-success-plan
description: Author a Kong customer success-plan JSON file (the input format kong-success-plan-pptx expects), extract whatever can be extracted from the user's existing context (running notes, call transcripts, prior plans, markdown drafts) and from Salesforce via the sfdc skill (Account, Contacts, Opportunity, recent Cases), ask the user only for what's still missing instead of fabricating it, run all customer-visible prose through the humanizer skill, render the deck via kong-success-plan-pptx, and visually verify the output. Use whenever the user asks to "write a success plan", "draft a success plan", "build a success plan for <customer>", "update the success plan", "turn these notes into a success plan", "fill out the success plan template", or describes any Kong customer-success-plan authoring task — even when they don't explicitly mention the PPTX or the JSON schema. Trigger on phrases like "success plan", "QBR plan", "customer success plan", "kong success plan", or "renewal cycle plan" combined with a customer reference. Do NOT trigger for generic project plans, non-customer success plans (engineering plans, product roadmaps), or PPTX-rendering requests with the JSON already prepared (that's kong-success-plan-pptx).
---

## What this skill does

Builds the *content* of a Kong customer success plan in the JSON format that `kong-success-plan-pptx` consumes, then hands it off to that skill to render and visually verifies the result. Two halves:

- **Extract first** — read whatever the user already gave you (markdown plans, call transcripts, running notes, the conversation history) and pull every fact you can.
- **Ask for the rest** — never fabricate stakeholder names, KPI numbers, dates, or dollar figures. If the data is missing, ask. The success plan goes in front of a real customer; invented details get caught and damage credibility.

This is a methodology skill. It pairs with three other skills:

- `kong-success-plan-pptx` — renders the JSON to a Kong-branded PPTX. Required follow-up.
- `humanizer` — strips AI tells from prose. Required for all customer-visible writing.
- `sfdc` — queries Salesforce read-only for Account / Contacts / Opportunity / Case data. Used to pre-fill stakeholder names, renewal dates, ARR signals, and recent escalation context before asking the user.

## Workflow

Follow these steps in order. Each one matters; don't skip ahead.

### 1. Inventory what's already there

Before asking the user anything, scan everything they've given you:

- Files they referenced (`@path/to/file.md`, attached PDFs, transcripts)
- Prior turns in the conversation (drafts, lists, partial plans)
- Any markdown success plan that already exists (often produced by `success-planning-framework` or earlier turns)
- Any call notes, meeting recap files, or Salesforce exports

Pull out every fact. Stakeholder names, product licenses, footprint numbers, dates, blockers, business outcomes the customer is chasing. Keep a running list — you'll use it to populate the JSON and to determine what's missing.

If a user-provided markdown plan already maps cleanly to the schema, your job is mostly translation. If they've only handed you a raw transcript, your job is synthesis.

### 1a. Pull missing facts from Salesforce before asking the user

Many of the fields the user would otherwise have to dictate are already in Salesforce. Before assembling your "missing data" question batch in step 3, invoke the `sfdc` skill to query the account directly. Asking the user for things SFDC already knows is a credibility hit — it signals you didn't do your homework.

Use this whenever the customer is a real account (not a hypothetical or sandbox example). If you only have a customer name, that's enough — the `sfdc` skill can resolve it to an Account record.

What's worth pulling, and where each field lands in the success plan:

| SFDC source | Field on the success plan |
|---|---|
| `Account.Name`, `Account.Site` | `customer.name` |
| `Account.OwnerId` → User → CSM/AE owner | `customer.csm`, `deep_dive.footer` |
| `Contact` records on the account (Name, Title, Role) | Stakeholder map for `deep_dive` owners and "asks" |
| `Opportunity` (open and recent closed/won) | Renewal/expansion context for `objectives.takeaway` and timelines |
| `Opportunity.CloseDate` for the renewal opp | Time horizon language ("through the renewal cycle") |
| Recent `Case` records (last 90 days, severity, status) | Risk signals — informs `deep_dive` bottlenecks and `workstreams` health framing |
| Custom CX fields (health score, RAG, last QBR date) | `workstreams.footer` KPI line, deep-dive context |

Operating rules:

- **Read-only.** Never invoke `sfdc` in a write mode from this workflow. Success plans are authored from current state, never modify it.
- **Treat SFDC as one source among many, not gospel.** If the user-provided notes contradict SFDC (e.g., a stakeholder left, an opportunity is no longer real), trust the more recent signal. Note the discrepancy in your final report.
- **Don't dump SFDC data into the deck verbatim.** Pull facts; synthesize prose. The slide-2 takeaway is not a copy-paste of an Account's description field.
- **If the user opted out** ("don't bother SFDC", "I'll give you everything", "this is hypothetical"), skip this step entirely. Honor the opt-out and proceed to step 2.

After SFDC enrichment, recompute your "what I have / what's missing" map. Often you'll find you only need to ask the user 1-2 things rather than 6.

### 2. Map what you have to the schema

The target schema (from `kong-success-plan-pptx`) has four sections. For each field, mark whether you have it, can synthesize it confidently, or need to ask:

```
customer:
  name              # ASK if not stated
  csm               # ALWAYS ASK (you cannot infer who's on the account)
  date              # ASK if not stated
  tagline           # SYNTHESIZE then confirm

objectives:
  takeaway          # SYNTHESIZE from the objectives, then confirm
  items[3]:         # 3 objectives — Kong arc is usually modernization / AI / consolidation;
                    #   adjust to fit the actual customer's stated goals
    heading         # SYNTHESIZE in ALL CAPS
    bullets         # SYNTHESIZE from notes; 1-2 short bullets per objective

workstreams:
  footer            # KPI line — ASK for specific numbers if not stated
  items[4]:         # 4 workstreams; common Kong tracks are AI Gateway, Insomnia,
                    #   Gateway/APIM consolidation, Developer Portal — vary by license
    title           # SYNTHESIZE
    date            # ASK if not stated (e.g. "Q3 2026")
    status          # SYNTHESIZE ("In Progress", "Complete", "Active", "At Risk")
    bullets         # SYNTHESIZE from notes; 1-3 short bullets per workstream

deep_dive: (optional, ask whether to include)
  footer            # OWNERS line — ASK for stakeholder names
  items[4]:         # one box per workstream
    title           # mirror workstream title (shorter form OK)
    date            # repurposed as "Owner: <Name>"
    status          # "Active" is a sane default
    bullets         # bottleneck + play + supporting action
```

When in doubt about whether something can be synthesized vs. needs asking: **err toward asking**. The cost of a bad assumption is much higher than the cost of one extra question.

### 3. Ask for missing data — batched, not one-at-a-time

If you have access to `AskUserQuestion`, use it to ask several missing items at once. Otherwise, ask in plain text but group related questions into a single message. Never drag the user through a 10-question interrogation.

A good batch looks like this:

> I have most of what I need from your notes. To finish the plan I need:
> 1. **Date for the cover slide** (e.g. "May 2026")
> 2. **CSM name** as it should appear on the cover
> 3. **KPI numbers for the slide-3 footer** — current footprint metrics worth highlighting (licensed services / API request volume / etc.)
> 4. **Deep-dive owners** for each workstream (CSM/SE/AE who owns it internally)

A bad batch is one question per turn. That burns the user's patience.

When you do have to ask multiple rounds, prioritize: ask once for the data that only the user can know (names, figures, dates), and synthesize/draft the rest. Then circle back with a single "here's the draft, anything to adjust?" instead of more questions.

### 4. Author the prose with care

The customer-visible prose lives in three places: the cover tagline, the objective bullets, and the workstream bullets (and deep-dive if included). Slide-2 prose is especially visible — the executive sponsor reads it first.

Length rules (from `kong-success-plan-pptx`):

- Cover tagline: one line, ~70 chars max
- Bottom-line takeaway: one sentence, ~30 words max
- Objective headings: ALL CAPS, 2-5 words
- Objective bullets: ~50-65 chars each; 1-2 bullets per objective; the third objective slot accepts a single descriptive sentence instead of a bullet list when that fits better
- Workstream bullets: ~50-65 chars each; 1-3 bullets per workstream; longer bullets clip
- Deep-dive bullets: same length, structured as `Bottleneck: ...` / `Play: ...` / supporting action
- Status pill text: 2-3 words ("In Progress", "Complete", "Active", "At Risk")

Why these limits matter: the template's text shapes have fixed widths. Bullets longer than ~65 characters wrap to three lines and start clipping at the bottom of the box, even with the height extension applied during rendering. Tight prose isn't a stylistic preference — it's a layout constraint.

### 5. Run every customer-visible string through the humanizer skill

Before you encode the prose into JSON, invoke the `humanizer` skill on every customer-visible string: cover tagline, takeaway, objective headings, objective bullets, workstream titles, workstream bullets, deep-dive bullets, KPI footer, owners footer.

Why: success plans are read by the customer's CTO and economic buyer. AI tells (em dashes, "leverage", "robust", inflated significance language, mechanical rule-of-three, sycophantic phrasing) read poorly in front of those audiences and undermine the CSM's credibility. Run prose through `humanizer` and apply the resulting cleaner version.

The status pill strings, the page numbers, and the legend can stay as-is — they're labels, not prose, and humanizer adds no value there.

### 6. Write the JSON content file

Write to a sensible default path next to the user's other materials. If they're working in `~/tmp/successplans/<customer>/`, use that. Otherwise ask. File name: `<customer>-success-plan.json` (lowercase, kebab-case).

Validate the JSON parses before continuing. A bad file fails the build script with an unhelpful error, costing a round-trip.

### 7. Render the PPTX via kong-success-plan-pptx

Invoke the build script. The skill is at `~/.claude/skills/kong-success-plan-pptx/`. Standard form:

```bash
python3 ~/.claude/skills/kong-success-plan-pptx/scripts/build.py \
  --input <path-to-content>.json \
  --output <Customer>-Kong-Success-Plan.pptx
```

If `python3` isn't on PATH (e.g., NixOS), prefix with `nix run nixpkgs#python3 --`.

If the script reports any "shapes not found" warnings, that means a replacement targeted a shape ID that doesn't exist in the bundled template — usually because a customer-supplied override added a key that isn't in the schema. Investigate and adjust.

### 8. Visually verify the rendered deck — required, not optional

After the PPTX renders, check it visually before reporting the task complete. Text replacement can succeed in XML and still produce overlapping shapes, clipped bullets, or off-template positioning that an automated check can't catch.

```bash
soffice --headless --convert-to pdf --outdir /tmp <Customer>-Kong-Success-Plan.pptx
nix shell nixpkgs#poppler-utils --command pdftoppm -r 110 -f 1 -l 4 \
  /tmp/<Customer>-Kong-Success-Plan.pdf /tmp/sp-slide -png
```

(On non-Nix systems use `pdftoppm` directly.)

Then read each PNG (`/tmp/sp-slide-1.png` through `-4.png`) with the Read tool and check:

- **Slide 1**: customer name correct, date correct, CSM name correct, tagline reads cleanly, no leftover placeholder strings (`<...>`)
- **Slide 2**: three objectives present, each heading uppercase, bullets fit cleanly, takeaway visible at bottom
- **Slide 3**: four workstreams present, each badge visible above its bullets (no overlap), bullets not clipped at the bottom of the box, KPI footer reads
- **Slide 4** (if included): four initiative boxes present, bottleneck/play structure consistent, owners footer reads

If anything is off, fix it (usually by tightening bullet length or correcting a wrong field) and re-render before reporting done. LibreOffice may show minor Z-order quirks on status pills that real PowerPoint resolves; if a render artifact only appears in soffice and the underlying XML looks correct, note it and move on.

### 9. Report what you produced

Tell the user:

- The JSON file path (so they can edit and re-render)
- The PPTX file path
- Anything you assumed or inferred that they should sanity-check (especially synthesized prose that only got humanizer-treated, not user-written)
- Any KPI numbers or stakeholder details they still owe (if you proceeded with placeholders)

## Authoring patterns

### Translating a markdown success plan into JSON

When the user already has a markdown success plan (e.g. from `success-planning-framework`), translate directly:

- Executive summary → cover tagline + takeaway
- Strategic objectives section → `objectives.items` (cap at 3, group if needed)
- Workstreams section → `workstreams.items` (cap at 4)
- Risk + immediate-actions sections → `deep_dive.items` (one box per workstream, surfacing the top blocker and play)

Don't include the entire markdown plan in the deck — the deck is a 4-slide summary, not a rewrite of the plan. The plan stays the source of truth; the deck is the executive view.

### Defaulting the Kong workstream structure

If the customer has a typical Kong license (Gateway + Insomnia + AI Gateway + Developer Portal), the default four workstreams are:

1. **AI Gateway adoption** — getting from licensed to first production use case
2. **Insomnia adoption** — getting from admin-only to active developer usage
3. **Gateway optimization / legacy consolidation** — tenant cleanup + pulling other gateways onto Kong
4. **Developer Portal modernization** — old-portal sunset + new-portal adoption + Service Catalog conversation

Adjust if the customer's license differs (e.g., Mesh-heavy customer swaps Mesh in for one of the four).

### Writing the bottom-line takeaway

The takeaway sentence on slide 2 is the most-quoted line of the deck. It should read:

> "These priorities are how we measure [Customer]'s [theme 1], [theme 2], and [theme 3] through the [time horizon]."

Themes match the three strategic objectives. Time horizon is usually "renewal cycle" or a specific quarter. Keep it under 30 words. Run through humanizer.

## What to ask vs. what to author

"Pull from SFDC" means use the `sfdc` skill against the customer's Account first; only ask the user if SFDC doesn't have it or the user opted out of SFDC enrichment.

| Field | Pull from SFDC | Ask | Author then confirm | Notes |
|---|---|---|---|---|
| Customer name | ✓ | ✓ | | SFDC `Account.Name`; ask if not in context and SFDC unavailable |
| Customer date | | ✓ | | "May 2026" format — usually the meeting/QBR date |
| CSM name | ✓ | ✓ | | SFDC Account owner / CSM field; confirm with user |
| Cover tagline | | | ✓ | Synthesize from the customer's stated goals |
| Bottom-line takeaway | | | ✓ | Synthesize from the three objectives |
| Objective headings | | | ✓ | ALL CAPS; ask if customer's language differs from typical Kong arc |
| Objective bullets | | | ✓ | From notes/transcripts |
| Workstream titles | | | ✓ | Default Kong tracks unless customer's license differs |
| Workstream dates | | ✓ | | Specific quarters/months — don't guess |
| Workstream status | | | ✓ | "In Progress" is a safe default for active accounts |
| Workstream bullets | | | ✓ | From notes |
| KPI footer numbers | ✓ | ✓ | | SFDC for ARR / renewal / health-score values; ask user for usage metrics SFDC doesn't track |
| Deep-dive bottlenecks | | | ✓ | From notes; SFDC recent Cases can corroborate |
| Deep-dive plays | | | ✓ | From notes |
| Deep-dive owners | ✓ | ✓ | | SFDC Account owner / opportunity team gives you AE; ask user for SE if not on the team |
| Deep-dive footer | ✓ | | | "OWNERS \| CSM \| AE \| SE" — composed from SFDC owners |

## Hard rules

- **Never fabricate names, figures, or dates.** If the user didn't supply them and they're not in the source material, ask.
- **Never ship a deck without running every customer-visible string through humanizer.** Even short bullets — humanizer matters most where the audience is highest.
- **Never report the task complete without a visual slide check.** XML success ≠ visual success.
- **Never silently truncate.** If a bullet is too long for the box, tighten the wording rather than letting the renderer clip it. The user can always lengthen later if they want.
- **Three objectives, four workstreams, no more.** The template has fixed slots. Group or trim if the customer's situation has more.

## Limitations

- Cannot embed images. The cover ships with the Kong Konnect mark only; if the customer logo is wanted on the cover, the user adds it in PowerPoint after rendering.
- Cannot generate the source markdown success plan from scratch. If no plan or notes exist, ask the user to draft one first (point them at the `success-planning-framework` skill) — this skill is for authoring the deck *content*, not deciding strategy from zero.
- LibreOffice-rendered PNGs occasionally show Z-order quirks on status pills that PowerPoint renders correctly. The visual check is for catching content errors (wrong field, clipped bullet, leftover placeholder), not chasing render-engine artifacts.
