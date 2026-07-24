# Filled example -- Nordstrom, "Service Mesh Canary Rollouts"

A worked example matching `account-risk-format.md`. Values are illustrative
(the real record lives in Salesforce); use it to match structure, tone, and
the level of specificity a good risk carries. The prose here is already the
kind of tight, dash-free output `text-polish` produces.

---

# Account Risk: Nordstrom -- Service Mesh Canary Rollouts

## Header

| Field | Value |
|---|---|
| Account Risk Name | Service Mesh Canary Rollouts |
| Days Active | (auto) |
| Trend | Decreasing |
| Owner | Dustin Krysak |
| Account | Nordstrom |
| CS Leader | CONFIRM |
| Opportunity | Nordstrom - Kong Mesh Renewal FY26 (open) |
| Account Owner | (AE on file) |
| Existing Contract ARR | $480,000 (Contract 00012345, Renewal_ACV__c) |
| Engagement Manager | CONFIRM |
| Renewal Close Date | 2026-03-31 |
| ELT Sponsor | CONFIRM |

## Risk Review

**Current Risk Level: Level 2 (Yellow)** -- Watching closely

*The Mesh renewal is on track on paper, but the canary rollout that justifies
the expansion has stalled, and the one person driving it has gone quiet.*

### 1. Impact
- **Specific Risk:** The phased canary rollout of Kong Mesh into the checkout
  path has been paused for six weeks. Without it, the FY26 expansion case
  loses its proof point.
- **Expansion / Revenue Impact:** $480,000 renewal ACV at stake, plus a
  planned $180,000 expansion tied directly to the checkout rollout. The
  expansion slips a quarter every month the rollout stays paused.
- **Strategic Risk:** Nordstrom is a named reference for Mesh in retail. A
  stalled rollout puts the reference at risk and opens the door to their
  internal "build vs. buy" faction.
- **Customer Sentiment:** The platform lead is still positive on Kong, but the
  checkout team has voiced latency concerns we have not yet closed out.

### 2. Playbook Check (Actions Taken So Far)
- Ran a joint architecture review with the platform team on the sidecar
  latency numbers.
- Escalated the checkout latency question to Kong support (ticket linked in
  the account folder).
- Booked a technical working session for the week of the renewal.

### 3. Help Needed (Specific Ask)
Need a Mesh product SME for one 60-minute session to close out the checkout
latency question before the renewal conversation. No exec escalation needed
yet.

## Account Details

| Field | Value |
|---|---|
| Customer Health | Yellow (62) |
| CXM Sentiment | Neutral |
| Business Health | Yellow |
| Relationship Health | Green |
| Stage | Adopt / Expand |
| Segment | Enterprise |
| Geo | AMER |
| Products Used | Kong Mesh, Kong Gateway Enterprise |
| Success Plan | (link in Google Drive folder) |

## Opportunity & Renewal Reconciliation

| Contract | End Date | Renewal ACV | Renewal Opp | Opp Amount | Note |
|---|---|---|---|---|---|
| 00012345 | 2026-03-31 | $480,000 | Nordstrom - Kong Mesh Renewal FY26 | $4,800 | DEFECT: opp Amount is 100x low vs contract ACV -- flag to AE/RevOps; trust the contract |

Renewal-hygiene note: the renewal opportunity Amount ($4,800) is off by two
orders of magnitude against the contract's Renewal_ACV__c ($480,000). Trust
the contract figure in the narrative and flag the opp for correction.

## Stakeholders

| Role | Name | Met? |
|---|---|---|
| Champion | Platform lead (name on file) | yes |
| Economic Buyer | VP Engineering | no -- CONFIRM |
| Technical Lead | Checkout team lead | yes |

## Salesforce write plan

- Object: Account_Risk__c (createable fields only)
- Name: `Service Mesh Canary Rollouts`
- Account__c: `<Nordstrom account id>`
- Type__c: `Late Deployment`
- Status__c: `1. Open`
- Source__c: `CSM Sentiment Update`
- Trend__c: `Decreasing`
- Opportunity__c: `<open FY26 Mesh renewal opp id>`
- Next_Steps__c: the Risk Review block above, as HTML (narrative-format.md)
- Help_Needed__c: the section-3 paragraph, plain text
- Mitigation_Plan__c: the section-2 actions
- Target org: `<alias / username>`
- No Account write. CS_Account_Notes__c untouched.
