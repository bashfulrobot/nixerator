# `Account_Risk__c` object: fields, picklists, gotchas

Read this before building the create payload. **Validate the picklists live
each run** -- values drift, and a stale value fails the write. Describe first:

```bash
bash scripts/sfdc-describe.sh Account_Risk__c --fields-only   # from the sfdc skill
```

Confirm the picklist sets below against the describe output. If they differ,
use the live values and update this file (SKILL.md Step 5).

## Createable fields

Set only what applies. Everything here is `createable = true`.

| Field | Type | Purpose |
|---|---|---|
| `Name` | text | Risk name / theme (short, specific). |
| `Account__c` | reference (Account) | The account the risk is on. Required. |
| `Type__c` | picklist | Risk category (see values). |
| `Status__c` | picklist | Lifecycle state (see values). New risks start `1. Open` (or `0. New`). |
| `Source__c` | picklist | What surfaced the risk (see values). |
| `Trend__c` | picklist | Engagement/risk trend (see values). |
| `CS_Leader__c` | reference (User) | CS leader. Often blank. |
| `Opportunity__c` | reference (Opportunity) | **Open opp only.** Leave blank for an account-level risk. |
| `Help_Needed__c` | long text (plain) | Short awareness paragraph / the specific ask. **Plain text, no HTML.** |
| `Mitigation_Plan__c` | long text | The mitigation plan. May be "none yet". |
| `Next_Steps__c` | rich text (HTML) | **The full structured narrative** (Risk Level line + Impact + Playbook + Help Needed). Write HTML per `narrative-format.md`. |
| `ELT_Actions__c` | long text | ELT actions, if any. |
| `ELT_Sponsor__c` | reference (User) | Usually blank. |
| `Engagement_Manager__c` | reference (User) | Usually blank. |
| `Get_Well_Plan__c` | long text | Get-well plan, if used. |
| `Save_Reason__c` | picklist/text | On save/close. |
| `Close_Justification__c` | long text | On close. |
| `Date_Closed__c` | date | On close. |
| `Risk_Review__c` | boolean | Risk-review flag. |

### Do NOT set
- `Renewal_Close_Date__c` -- read-only rollup.
- `Renewal_Risk_Level__c` -- read-only rollup.
- Anything on the **Account** object. In particular never write
  `Account.CS_Account_Notes__c` (the CSM Exec Summary) from this flow.

### There is no "Impact" or "Risk Level" field
The risk level and the whole Impact / Playbook / Help-Needed narrative live
inside `Next_Steps__c` as rich text. That is by design and is confirmed
against a completed record. Do not go looking for a separate level field.

## Picklist values (validate live each run)

Current sets. Case-sensitive.

**`Type__c`**
- `Lack Of Champion`
- `No Budget / Lost Funding`
- `Pain not big enough`
- `Value/Price`
- `Missing Technical Criteria`
- `Lost to Competitor`
- `Duplicate / Created In Error`
- `Customer hasn't provided reason yet`
- `Late Deployment`
- `Product - Feature Request`
- `ENG - Bug`

**`Status__c`**
- `0. New`
- `1. Open`
- `2. Resolved`
- `3. Confirmed Churn`
- `4. Created By Error`

**`Source__c`**
- `CSM Sentiment Update`
- `Renewal Risk Update`
- `Overall Health Score`
- `Late Deployment`

**`Trend__c`**
- `Increasing`
- `Stable`
- `Decreasing`

There is **no** "Worsening" value. Map a worsening trend -> `Decreasing`.

## Getting the field mapping right: read a completed record

The most reliable way to confirm the HTML/field mapping is to read a real,
completed risk record's field values -- not a PDF or screenshot. The
reference is the Nordstrom "Service Mesh Canary Rollouts" record. If you have
its Id:

```sql
SELECT Id, Name, Type__c, Status__c, Source__c, Trend__c,
       Next_Steps__c, Help_Needed__c, Mitigation_Plan__c
FROM Account_Risk__c
WHERE Id = '<nordstrom-example-id>'
```

Reading `Next_Steps__c` back shows the exact rich-text pattern Salesforce
stored (section headers in `<strong>`, bulleted points, a coloured risk-level
line). Use it to confirm the mapping; use `narrative-format.md` for the actual
markup and colours (cleaner and more legible than the original).

## Gotchas

1. **Closed Won opp linkage is blocked.** Linking a Closed Won opp to the risk
   throws:
   `CANNOT_EXECUTE_FLOW_TRIGGER: Closed Won Opportunity can not be updated
   manually from the "Account Risk Creation or Update" flow.`
   This is why Step 2 presents open opps only. If a create fails this way,
   fall back to an open renewal opp or a blank `Opportunity__c`, tell the
   user, and rebuild the payload. A closed opp the CSM wants referenced goes
   in the narrative text, not in `Opportunity__c`.

2. **`Opportunity.Amount` is unreliable.** Real examples: a $12.7B and a $220M
   closed-lost opp, a renewal opp inflated 100x, a $0 renewal shell on a live
   contract. Trust `Contract.Renewal_ACV__c` / `Renewal_TCV__c`. Surface any
   renewal-hygiene defect (a $0 or wildly-off renewal) as a finding for the
   AE/RevOps.

3. **`SBQQ__Subscription__c` is not queryable** (no access). Rely on
   Contract-level ACV/TCV for the renewal money.

4. **`sf data create --values` is fragile for multi-line/HTML textareas.** Use
   the REST create (`create-account-risk.sh`) with a jq-built body. Never
   hand-concatenate HTML into a `--values` string.

5. **Picklists drift.** Always describe live before the write.

## Write endpoint

```
POST /services/data/vXX/sobjects/Account_Risk__c
```

`create-account-risk.sh` handles the version, the POST, the org echo, and the
read-back verify.
