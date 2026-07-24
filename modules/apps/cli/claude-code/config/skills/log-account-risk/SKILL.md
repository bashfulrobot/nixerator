---
name: log-account-risk
description: >-
  Log a Kong Account Risk end to end -- pull the account's live Salesforce
  data, run a focused Q&A to fill only the human-knowledge gaps, build the
  risk narrative in Kong's standard "Account Risk" format, and write one
  Account_Risk__c record to Salesforce. Use whenever the user (a Kong CSM)
  wants to raise, log, or record a churn/renewal/adoption risk on a customer
  account. Trigger on "/log-account-risk", "log an account risk", "raise a
  risk on this account", "create an account risk record", "log a churn risk
  in SFDC", "record a renewal risk", "flag an account as at-risk", or any
  request to capture a customer risk into Salesforce. Trigger eagerly even
  when the user only hints at a risk on a named account. Composes the sfdc,
  kong-technical-csm, and text-polish skills. Do NOT trigger for building a
  Success Plan (that is csp-draft), a support Case (log-support-ticket), or a
  feature request (feature-request); those are separate objects with their
  own skills.
---

# Log Account Risk

Raise a Kong Account Risk on a customer and write it to Salesforce as one
`Account_Risk__c` record. The workflow is deliberately **research-first**:
Salesforce already holds most of the answer (health scores, renewal math,
consumption, the AI health summary), so pull that *before* asking the CSM
anything. Then ask only for the human knowledge Salesforce cannot know --
what the CSM has heard, who they have actually met, what they intend to do.

## Why this skill exists

A CSM logging a risk by hand does three tedious things badly: they re-key
data that is already in Salesforce, they eyeball a risk level instead of
reconciling it against the health fields, and they hand-format a rich-text
narrative that renders inconsistently. This skill removes all three. It reads
the real account, reconciles the risk level against the health picklists out
loud, and emits a clean, legible narrative into the one field that is built
to hold it -- `Account_Risk__c.Next_Steps__c` -- without ever touching the
CSM's own sentiment log.

## What this composes with (call, do not reimplement)

- **sfdc** -- every Salesforce read and the single write. All reads use its
  query/describe scripts; the write follows its `writes-playbook.md` (org
  echo, plan, explicit confirm, verify). This skill only swaps the *execution
  mechanic* in the playbook's step 7 (REST create, not `sf data create`) --
  see Step 4.
- **kong-technical-csm** -- Kong account context, health-signal
  interpretation, stakeholder framing. Lean on it when judging what the data
  means for the account.
- **text-polish** -- every piece of generated prose. Non-negotiable; see the
  banner below.

## All generated prose goes through text-polish

Any sentence this skill writes that a human will read -- the Impact bullets,
the Help Needed paragraph, the risk framing line, anything in the markdown
doc -- **must** be run through the `text-polish` skill before it lands in the
document or the Salesforce payload. That is the humanize + concision pass:
no em/en dashes, no AI throat-clearing, tight prose. Route the prose through
`text-polish`, then place the polished result.

Do **not** polish structured data: field values, IDs, table cells, picklist
values, dates, money, or any text copied verbatim from Salesforce. Polishing
those would corrupt them. Polish prose; leave data alone.

## Workflow

Five steps: resolve + pull (reads) -> Q&A (gaps only) -> build markdown ->
write to Salesforce (one confirmed create) -> persist learnings.

### Step 1 -- Resolve the account and pull its data (reads)

Goal: walk into the Q&A already knowing everything Salesforce knows.

1. **Resolve the account Id.** Check the warm cache first:
   `skill-cache get sfdc accounts "<name>"`. On a hit, use the Id. On a miss,
   resolve with a `SELECT Id FROM Account WHERE Name = '<name>'` (via the sfdc
   query script) and write it back with `skill-cache put` (see Step 5).
2. **Confirm the target org**, filtered so the access token never prints:
   ```bash
   sf org display --json | jq -r '.result | "\(.alias // "<no alias>") / \(.username) / \(.instanceUrl)"'
   ```
   Echo the org identity to the user now, and again in the write plan.
3. **Pull the account, opportunities, contracts, and existing risks.** The
   exact SOQL, the full Account custom-field list, and the
   contract->renewal-opp reconciliation live in
   `references/sfdc-queries.md`. Read that file and run the queries. Key
   points that file expands on:
   - `AI_Health_Summary__c` is a goldmine -- it often already contains the
     stakeholder map, renewal math, consumption, risks, and recommended
     actions. Read it before asking the CSM anything.
   - `CS_Account_Notes__c` (CSM Exec Summary) is context only; **never write
     to it** in this flow.
   - Reconcile each Contract to its renewal Opportunity via
     `Opportunity.SBQQ__RenewedContract__c`. Report any contract with no
     renewal opp, and flag broken values.
   - Trust `Contract.Renewal_ACV__c` / `Renewal_TCV__c` over `Opportunity.Amount`
     (Amount is unreliable -- real examples include a $12.7B opp and a
     100x-inflated renewal). Surface renewal-hygiene defects as a finding.
   - Check for existing `Account_Risk__c` records: `WHERE Account__c = '<id>'`.
     If an open risk already exists, surface it -- the CSM may want to update
     rather than duplicate.

Summarize what you pulled before moving on, so the CSM sees you did the
homework and can correct any stale data.

### Step 2 -- Q&A: fill only the gaps (AskUserQuestion)

Ask only for what Salesforce cannot tell you. Use `AskUserQuestion` for the
structured picks. Cover:

- **Risk name / theme** -- short, specific (e.g. "Service Mesh Canary
  Rollouts stalled").
- **Risk level** -- Green / Yellow / Red. If the health fields disagree with
  the CSM's call, **say so and reconcile out loud** -- do not silently pick
  one. ("Customer_Health__c says Red; you're calling it Yellow -- confirm
  you're dropping it, and I'll note why.")
- **Risk drivers** (multi-select) -- these become the "1. Impact" bullets.
- **Engagement trend** -- maps to `Trend__c` (Increasing / Stable /
  Decreasing; there is no "Worsening" -- map worsening -> Decreasing).
- **Which opportunity to anchor** -- **filter to open opps only**
  (`IsClosed = false`) and present those. Do **not** offer Closed Won/Lost
  opps: a Salesforce flow blocks linking a Closed Won opp and the create will
  fail (see `references/account-risk-object.md`). If the CSM wants a closed
  opp referenced, name it in the narrative text, not in `Opportunity__c`. If
  there are no open opps, offer to leave `Opportunity__c` blank
  (account-level risk).
- **Help-needed posture** -- awareness-only vs a specific ask.
- **Mitigation plan** -- may legitimately be "none yet".
- **Stakeholder map** -- champion, economic buyer, technical leads, and
  crucially who the CSM has *actually met* vs. names on file.
- **CS Leader / ELT Sponsor / Engagement Manager** -- confirm; often
  unassigned, and that is fine (leave the User refs blank).

Reconcile every field discrepancy in the open. The point of pulling the data
first was to make these conflicts visible.

### Step 3 -- Build the markdown document

Write the risk to the customer's `risk/` folder (under their account folder;
confirm the path with the CSM if unsure), mirroring
`references/account-risk-format.md`. The three blocks are the Account Risk
header, the Risk Review narrative, and the Account/Opportunity details. See
`references/account-risk-example.md` for a filled example.

**Run the narrative prose through `text-polish`** -- the Impact bullets, the
Help Needed paragraph, the risk framing line. Leave tables, field values, IDs,
dates, and any verbatim SFDC notes untouched. Mark genuine unknowns as
`CONFIRM` or `TODO`; never invent a value.

The markdown doc is the human-readable artifact and the source you translate
into the Salesforce rich-text field in Step 4.

### Step 4 -- Write to Salesforce (one confirmed create)

One production write: create a single `Account_Risk__c`. Follow the sfdc
`writes-playbook.md` discipline (understand -> confirm org -> describe ->
plan -> explicit "yes" -> execute -> verify). The **only** deviation is the
execution mechanic: use a REST create with a jq-built JSON body, not
`sf data create --values` (which is fragile for multi-line HTML).

Before building the payload, read `references/account-risk-object.md` for the
createable field list, the picklist values, and the gotchas, and
`references/narrative-format.md` for the exact rich-text HTML standard.

Field mapping (full detail in `references/account-risk-object.md`):
- `Next_Steps__c` (rich text / HTML) carries the **entire** structured
  narrative: the "Risk Level: Level N (Colour)" line, "1. Impact",
  "2. Playbook Check", "3. Help Needed". Build the HTML per
  `references/narrative-format.md`.
- `Help_Needed__c` (plain text) holds **only** the short awareness paragraph
  -- the specific ask, or "No specific ask at this time." No HTML.
- Scalars: `Name`, `Account__c`, `Type__c`, `Status__c`, `Source__c`,
  `Trend__c`, `CS_Leader__c`, `Opportunity__c` (open opp only),
  `Mitigation_Plan__c`, and the usually-blank User refs.
- Do **not** set `Renewal_Close_Date__c` or `Renewal_Risk_Level__c`
  (read-only rollups). Do **not** touch the Account.

**Validate the picklists live each run** -- values drift. Before the write,
`bash scripts/sfdc-describe.sh Account_Risk__c --fields-only` (via the sfdc
skill) and confirm `Type__c`, `Status__c`, `Source__c`, `Trend__c` against
the current picklist set. If they drifted from
`references/account-risk-object.md`, use the live values and update the
reference (Step 5).

Build and execute the write with the bundled helpers:

```bash
# 1. Write the Next_Steps__c HTML to a file (per narrative-format.md).
#    Write the Help_Needed__c plain text to a second file.
#    Write the scalar fields as a JSON object to a third file.
# 2. Build the payload -- HTML/text are loaded via jq --rawfile, never
#    hand-concatenated into a string:
bash scripts/build-risk-payload.sh \
  --fields fields.json \
  --html next_steps.html \
  --help-file help_needed.txt > payload.json

# 3. Show the user the plan block (org, object, every scalar field, and the
#    rendered narrative) and get an explicit "yes" per the writes-playbook.

# 4. Execute the REST create (echoes the org, POSTs, reads the record back):
bash scripts/create-account-risk.sh --payload payload.json
```

`create-account-risk.sh` POSTs to
`/services/data/vXX/sobjects/Account_Risk__c`, captures the new Id, and
re-reads the record to verify. If the create fails with
`CANNOT_EXECUTE_FLOW_TRIGGER` (Closed Won opp linkage), fall back to an open
renewal opp or a blank `Opportunity__c`, tell the user why, and rebuild the
payload. See `references/account-risk-object.md` for the full gotcha list.

### Step 5 -- Persist learnings

- **skill-cache**: cache the account Id you resolved --
  `skill-cache put sfdc accounts "<name>" '{"id":"001..."}' --alias "<short>"`.
  If picklists or field API names drifted, update
  `references/account-risk-object.md`.
- **auto-memory**: save the reusable account context -- the team/renewal
  picture and the risk you raised -- as a concise fact. Not the transient
  query output; the durable shape of the account.

## Guardrails

- **Read-only by default.** The single write goes through the writes-playbook
  with per-run explicit confirmation and the target org echoed in the plan.
- **Never print secrets.** Always filter `sf org display` through `jq`; never
  print the access token.
- **Never invent field values.** Mark unknowns `CONFIRM`. A blank, honest
  field beats a confident wrong one.
- **Leave `CS_Account_Notes__c` alone.** It is the CSM's own dated sentiment
  log and renders next to the risk on the page layout, which makes the two
  easy to conflate. The risk narrative goes in `Next_Steps__c`, never there.
- **All prose through text-polish.** No exceptions for "quick" text.

## Files in this skill

### references/
- `sfdc-queries.md` -- the exact reads: account custom-field list, opp and
  contract queries, contract->renewal-opp reconciliation, existing-risk check.
- `account-risk-format.md` -- the three-block "Account Risk" document layout.
- `account-risk-example.md` -- a filled example to match structure against.
- `narrative-format.md` -- the `Next_Steps__c` rich-text HTML standard plus a
  fill-in skeleton. Read before building the payload.
- `account-risk-object.md` -- `Account_Risk__c` createable fields, current
  picklist values, field mapping, and the known gotchas.

### scripts/
- `build-risk-payload.sh` -- builds the create JSON body, loading the
  `Next_Steps__c` HTML and `Help_Needed__c` text via `jq --rawfile` (never
  string-concatenated).
- `create-account-risk.sh` -- echoes the org, POSTs the payload via
  `sf api request rest`, captures the new Id, and reads the record back to
  verify.
