# Account Risk — Kong standard format

The layout of a Kong "Account Risk" record and the markdown document that mirrors
it. Read this before building the doc in Step 3, and before mapping fields to the
`Account_Risk__c` payload in Step 4. The canonical reference is a completed
Salesforce Account Risk record (Nordstrom, "Service Mesh Canary Rollouts"), kept
as a PDF in the customer's `risk/` folder and reproduced as `example-nordstrom.md`.
If a reference PDF is present in the working directory, read it and match its
layout over anything written here.

A completed risk has three blocks. Block 1 and 2 live on the `Account_Risk__c`
record; block 3 lives on the `Account` object and is usually already maintained
by the CSM.

---

## Block 1 — Account Risk header

Identity and roll-up fields. Most are references pulled from Salesforce, not
authored. Present as a two-column table in the markdown.

| Field | Source | Notes |
|-------|--------|-------|
| Account Risk Name | authored | Short risk theme, e.g. "Service Mesh Canary Rollouts". Becomes `Name`. |
| Days Active | auto | Rollup on the record; do not set. Derived from created date. |
| Trend | authored | Increasing / Stable / Decreasing. Becomes `Trend__c`. |
| Owner | SFDC | Record owner (defaults to the creating user). |
| Account | SFDC | Lookup to the Account. Becomes `Account__c`. |
| CS Leader | SFDC | User lookup. Becomes `CS_Leader__c`. Often unassigned — CONFIRM. |
| Opportunity | SFDC | Single lookup to an **open** opp only. Becomes `Opportunity__c`. |
| Account Owner | SFDC | The AE on the Account. Read-only context. |
| Existing Contract ARR | SFDC | From the Contract, not the opp Amount (see gotchas). |
| Engagement Manager | SFDC | User lookup. Becomes `Engagement_Manager__c`. Often blank. |
| Renewal Close Date | SFDC rollup | Read-only. Do **not** set `Renewal_Close_Date__c`. |
| ELT Sponsor | SFDC | User lookup. Becomes `ELT_Sponsor__c`. Often blank. |

## Block 2 — Risk Review narrative

The heart of the record. A structured prose block. This same block is what gets
**prepended** to the Account's CSM Exec Summary (`CS_Account_Notes__c`) in Step 4,
because `Account_Risk__c` has no dedicated "Risk Level" or "Impact" field. Use
this exact skeleton:

```
Current Risk Level: Level N (colour)

1. Impact
   - Specific Risk: <what is actually at risk, concretely>
   - Expansion / Revenue Impact: <ARR/TCV exposed; expansion blocked>
   - Strategic Risk: <reference-ability, competitive displacement, exec relationship>
   - Customer Sentiment: <how the customer feels; reconcile with health fields>

2. Playbook Check (Actions Taken So Far)
   - <mitigation steps already run; "none yet" is a legitimate answer>

3. Help Needed (Specific Ask)
   - <awareness-only, or a concrete ask of CS leadership / the account team>
```

Risk Level ↔ colour mapping (reconcile against the health fields; if they
disagree, say so out loud rather than silently picking one):

| Level | Colour | Meaning |
|-------|--------|---------|
| Level 1 | Green | Healthy; logged for awareness / early signal. |
| Level 2 | Yellow | Real risk with a path; needs attention. |
| Level 3 | Red | Renewal / churn exposure; needs help. |

The `Help_Needed__c` field on the record gets **only** the awareness/ask
paragraph (block 2, section 3). The full block 2 goes into the Exec Summary.

## Block 3 — Account Details + Opportunity / renewal reconciliation

Context maintained on the `Account` object. Present as two tables in the doc.
These are reads — you report them, you do not author them.

**Account Details panel** (Account custom fields):

- Customer_Health__c, Customer_Health_Number__c
- CXM_Sentiment_Picklist__c
- Customer_Business_Health__c, Relationship_Health__c (+ their `*_Comments__c`)
- Customer_Stage_Picklist__c, GEP_Stage__c
- Account_Segment__c, Sales_Geo__c
- Kong_Enterprise_Products_Used__c, Gateway_API_Services_Used__c, ServicesText__c
- Insomnia_* fields, Customer_Outlook_* drivers
- Google_Drive_Folder__c, Customer_Success_Plan__c
- AI_Health_Summary__c — often already holds the stakeholder map, renewal math,
  consumption, risks, and recommended actions. **Mine it before asking anything.**
- CS_Account_Notes__c — the CSM Exec Summary (the field written in Step 4).

**Opportunity / renewal reconciliation table:** one row per Contract, joined to
its renewal opp via `Opportunity.SBQQ__RenewedContract__c`. Columns: Contract #,
Contract ARR (`Renewal_ACV__c`), Contract TCV (`Renewal_TCV__c`), Renewal Opp,
Opp Stage, Opp Amount, Renewal Close Date. Flag any contract with no renewal opp,
and flag opp `Amount` values that contradict the contract ACV/TCV as renewal
hygiene defects for the AE / RevOps.

---

## Markdown document skeleton

Write the doc to the customer's `risk/` folder. Mirror the reference PDF if one is
present; otherwise use:

```markdown
# Account Risk — <Account> — <Risk Name>

## Header
<Block 1 table>

## Risk Review
<Block 2 narrative — the structured skeleton>

## Account Details
<Block 3 Account Details table>

## Opportunity & Renewal Reconciliation
<Block 3 reconciliation table>

## Salesforce write plan
- Account_Risk__c payload (createable fields only)
- CS_Account_Notes__c prepend block
- Target org: <alias / username>
```

Prose sections (Impact, Help Needed, the Exec Summary block) run through
`text-polish`. Tables, field values, IDs, and verbatim SFDC notes stay untouched.
Mark genuine unknowns `CONFIRM` or `TODO` — never invent a value.
