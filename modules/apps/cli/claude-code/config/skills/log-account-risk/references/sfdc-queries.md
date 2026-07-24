# Step 1 reads: the account data pull

Run these through the **sfdc** skill's query script
(`bash scripts/sfdc-query.sh ...` from the sfdc skill, or the equivalent
`sf data query`). Confirm the target org first, filtered through `jq` so the
access token never prints (see SKILL.md Step 1).

The aim is to walk into the Q&A already knowing everything Salesforce knows,
so the CSM is only asked for human knowledge.

## Contents
- Account custom fields (the data-avoidance + Account Details panel pull)
- Opportunities (open + closed, for anchoring and renewal math)
- Contracts (the trustworthy source of renewal money)
- Contract -> renewal-opp reconciliation
- Existing Account_Risk__c records
- Reading the AI health summary
- Data-hygiene defects to surface

---

## Account custom fields

Pull these in one query. They serve two purposes: they populate the Account
Details panel of the risk doc, and they stop you asking the CSM for anything
Salesforce already knows.

```sql
SELECT Id, Name,
  Customer_Health__c, Customer_Health_Number__c, CXM_Sentiment_Picklist__c,
  Customer_Business_Health__c, Customer_Business_Health_Comments__c,
  Relationship_Health__c, Relationship_Health_Comments__c,
  Customer_Stage_Picklist__c, GEP_Stage__c,
  Account_Segment__c, Sales_Geo__c,
  Kong_Enterprise_Products_Used__c, Gateway_API_Services_Used__c,
  ServicesText__c,
  Google_Drive_Folder__c, Customer_Success_Plan__c,
  Insomnia_Users__c, Insomnia_Paid_Users__c, Insomnia_Last_Activity__c,
  Customer_Outlook__c, Customer_Outlook_Positive_Drivers__c,
  Customer_Outlook_Negative_Drivers__c,
  AI_Health_Summary__c,
  CS_Account_Notes__c
FROM Account
WHERE Id = '<account-id>'
```

Notes:
- **The exact `Insomnia_*` and `Customer_Outlook_*` API names vary by org.**
  If a field errors as not-found, drop it and describe the Account
  (`bash scripts/sfdc-describe.sh Account --fields-only`) to find the real
  name, then note the correction. Do not guess.
- `AI_Health_Summary__c` -- read this first and in full. It frequently already
  contains the stakeholder map, renewal math, consumption trend, live risks,
  and recommended actions. Much of the Q&A may already be answered here.
- `CS_Account_Notes__c` (the CSM Exec Summary) is **read for context only**.
  This skill never writes to it.
- `Customer_Health__c` / `Customer_Health_Number__c` / `CXM_Sentiment_Picklist__c`
  are the fields you reconcile the CSM's risk-level call against in Step 2.

## Opportunities

Pull all opps for renewal reconciliation, but remember: **only open opps**
(`IsClosed = false`) are eligible to anchor the risk (`Opportunity__c`).

```sql
SELECT Id, Name, StageName, IsClosed, IsWon, CloseDate, Amount,
       Type, SBQQ__RenewedContract__c
FROM Opportunity
WHERE AccountId = '<account-id>'
ORDER BY CloseDate DESC
```

- Present only `IsClosed = false` opps as anchor choices in Step 2.
- `Amount` is **unreliable** -- see the defects section. Do not quote it as
  the renewal number without cross-checking the contract.

## Contracts

Contracts are the trustworthy source of renewal money.

```sql
SELECT Id, ContractNumber, Status, StartDate, EndDate,
       Renewal_ACV__c, Renewal_TCV__c
FROM Contract
WHERE AccountId = '<account-id>'
ORDER BY EndDate DESC
```

- `SBQQ__Subscription__c` is **not queryable** (no access on these orgs).
  Rely on Contract-level `Renewal_ACV__c` / `Renewal_TCV__c`.
- If the field API names differ, describe the Contract object.

## Contract -> renewal-opp reconciliation

Each live contract should have a renewal opportunity that points back to it
via `Opportunity.SBQQ__RenewedContract__c`. Reconcile them:

1. For each Contract Id, find the opp whose `SBQQ__RenewedContract__c` equals
   that Id.
2. Report any contract with **no** renewal opp -- that is a renewal-hygiene
   gap worth flagging to the AE/RevOps.
3. Compare the opp `Amount` to the contract `Renewal_ACV__c`/`Renewal_TCV__c`.
   A wild mismatch (e.g. a $0 renewal shell on a live contract, or a
   100x-inflated Amount) is a defect -- surface it as a finding, and trust
   the contract number in the narrative.

```sql
SELECT Id, Name, StageName, IsClosed, Amount, SBQQ__RenewedContract__c
FROM Opportunity
WHERE SBQQ__RenewedContract__c IN ('<contract-id-1>', '<contract-id-2>')
```

## Existing Account_Risk__c records

Check before creating, so you do not duplicate an open risk.

```sql
SELECT Id, Name, Type__c, Status__c, Trend__c, Source__c,
       Opportunity__c, CreatedDate
FROM Account_Risk__c
WHERE Account__c = '<account-id>'
ORDER BY CreatedDate DESC
```

If an open risk already exists (`Status__c` in `0. New` / `1. Open`), surface
it to the CSM. They may want to update the existing record rather than raise a
second one. Logging a fresh risk is still valid (e.g. a genuinely new theme);
just make the choice explicit.

## Data-hygiene defects to surface

These are real patterns seen on live accounts. When you hit one, name it as a
finding for the AE/RevOps rather than silently trusting the bad value:

- `Opportunity.Amount` wildly wrong -- a $12.7B or $220M closed-lost opp, a
  renewal opp inflated 100x, or a $0 renewal shell sitting on a live paid
  contract.
- A live contract with **no** renewal opportunity at all.
- A renewal opp whose `Amount` disagrees with the contract's
  `Renewal_ACV__c`/`Renewal_TCV__c`.

Trust the contract's renewal fields over the opp `Amount` every time.
