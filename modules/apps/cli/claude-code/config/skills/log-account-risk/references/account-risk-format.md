# Account Risk document layout

The markdown doc mirrors Kong's completed Salesforce "Account Risk" record.
It has three blocks. The canonical example is the Nordstrom "Service Mesh
Canary Rollouts" record; if a reference PDF is present in the working
directory, read it and match its layout exactly. `account-risk-example.md` is
a filled version of this skeleton.

Write the doc to the customer's `risk/` folder. Field *values* and tables stay
verbatim; only the narrative prose (Impact, Playbook, Help Needed) is polished
through `text-polish`.

> Placement reminder: the Risk Review narrative goes into the risk record's
> `Next_Steps__c` field (rich text). It does **not** go on the Account. Never
> write it to `Account.CS_Account_Notes__c` (the CSM Exec Summary) -- that is
> the CSM's own dated sentiment log and is left untouched by this flow.

---

## Block 1 -- Account Risk header

A short field list. `Days Active` is auto-calculated by Salesforce; leave it
as a placeholder in the doc.

```markdown
# Account Risk: <Risk Name>

| Field | Value |
|---|---|
| Account Risk Name | <Risk Name> |
| Days Active | (auto) |
| Trend | <Increasing / Stable / Decreasing> |
| Owner | <CSM> |
| Account | <Account Name> |
| CS Leader | <name or CONFIRM> |
| Opportunity | <open opp name, or "account-level (none)"> |
| Account Owner | <AE> |
| Existing Contract ARR | <$ from Contract.Renewal_ACV__c> |
| Engagement Manager | <name or CONFIRM> |
| Renewal Close Date | <date> |
| ELT Sponsor | <name or CONFIRM> |
```

## Block 2 -- Risk Review narrative

The structured block, and the heart of the record. This is the text that
becomes the `Next_Steps__c` rich-text field in Salesforce (see
`narrative-format.md` for the HTML). In the markdown doc, write it as readable
markdown:

```markdown
## Risk Review

**Current Risk Level: Level N (<Colour>)** -- <one-word status>

*<one-line italic framing of the risk>*

### 1. Impact
- **Specific Risk:** <what is actually at risk>
- **Expansion / Revenue Impact:** <$ and %, tied to the contract number>
- **Strategic Risk:** <broader account/relationship stakes>
- **Customer Sentiment:** <what the CSM has heard, from whom>

### 2. Playbook Check (Actions Taken So Far)
- <action 1>
- <action 2>

### 3. Help Needed (Specific Ask)
<the specific ask, or "No specific ask at this time -- awareness only.">
```

Risk-level ↔ colour mapping (reconcile against the health fields; if they
disagree, say so out loud rather than silently picking one):

| Level | Colour | Meaning |
|---|---|---|
| Level 1 | Green | Healthy; logged for awareness / early signal. |
| Level 2 | Yellow | Real risk with a path; needs attention. |
| Level 3 | Red | Renewal / churn exposure; needs help. |

Field split on the record:
- The **whole** block 2 (Risk Level line + Impact + Playbook + Help Needed)
  goes into `Next_Steps__c` as HTML.
- Only the section-3 awareness/ask paragraph goes into `Help_Needed__c`, as
  plain text.

See `narrative-format.md` for the exact RGB colours chosen for legibility on
white.

## Block 3 -- Account Details + Opportunity / renewal reconciliation

Account Details live on the `Account` object and are usually already
maintained by the CSM; reproduce them for context (reads, not authored). Then
the renewal reconciliation -- this is where you surface any data-hygiene
defect.

```markdown
## Account Details

| Field | Value |
|---|---|
| Customer Health | <Customer_Health__c> (<Customer_Health_Number__c>) |
| CXM Sentiment | <CXM_Sentiment_Picklist__c> |
| Business Health | <Customer_Business_Health__c> |
| Relationship Health | <Relationship_Health__c> |
| Stage | <Customer_Stage_Picklist__c> / <GEP_Stage__c> |
| Segment | <Account_Segment__c> |
| Geo | <Sales_Geo__c> |
| Products Used | <Kong_Enterprise_Products_Used__c> |
| Success Plan | <Customer_Success_Plan__c link> |

## Opportunity / Renewal Reconciliation

| Contract | End Date | Renewal ACV | Renewal Opp | Opp Amount | Note |
|---|---|---|---|---|---|
| <ContractNumber> | <EndDate> | <Renewal_ACV__c> | <opp name / MISSING> | <Amount> | <defect flag or OK> |

<Narrative note on any renewal-hygiene defect found: a $0 or wildly-off
renewal, or a live contract with no renewal opp. Trust the contract ACV.>
```

The `AI_Health_Summary__c` field often already holds the stakeholder map,
renewal math, consumption, risks, and recommended actions -- mine it before
asking the CSM anything. `CS_Account_Notes__c` is read for context only and is
never written by this flow.

## Stakeholder map (optional block, recommended)

If the Q&A produced a stakeholder map, include it -- who the CSM has actually
met vs. names on file is high-signal for a risk.

```markdown
## Stakeholders

| Role | Name | Met? |
|---|---|---|
| Champion | <name or CONFIRM> | <yes/no> |
| Economic Buyer | <name or CONFIRM> | <yes/no> |
| Technical Lead | <name or CONFIRM> | <yes/no> |
```

---

## Full document skeleton

```markdown
# Account Risk: <Account> -- <Risk Name>

## Header
<Block 1 table>

## Risk Review
<Block 2 narrative>

## Account Details
<Block 3 Account Details table>

## Opportunity & Renewal Reconciliation
<Block 3 reconciliation table>

## Stakeholders
<optional stakeholder table>

## Salesforce write plan
- Object: Account_Risk__c (createable fields only)
- Next_Steps__c: the block-2 narrative as HTML (narrative-format.md)
- Help_Needed__c: the section-3 awareness paragraph, plain text
- Target org: <alias / username>
- (No Account write. CS_Account_Notes__c untouched.)
```

Prose sections (Impact, Help Needed, the risk framing line) run through
`text-polish`. Tables, field values, IDs, and verbatim SFDC notes stay
untouched. Mark genuine unknowns `CONFIRM` or `TODO` -- never invent a value.
