# Pulling contracted entitlement from Salesforce

How to get the authoritative "what they bought" for a renewal, and decode it correctly. Run
everything through the `sfdc` skill (read-only; it owns org confirmation and the query scripts).
Replace the example IDs/names with the live account.

## 1. Find the right account

The renewal is frequently NOT under the obvious name. A prospect record matching the customer's
common name may be stale (no opps/contracts) while the real paper sits under a parent or renamed
legal entity. Search wide, then follow the money, not the name.

```sql
-- obvious name (often a dead end)
SELECT Id, Name, Type FROM Account WHERE Name LIKE '%<name>%'

-- follow opps named for the customer across ALL accounts — this reveals the real account
SELECT Id, Name, Account.Name, StageName, Type, Amount, CloseDate
FROM Opportunity WHERE Name LIKE '%<name>%' ORDER BY CloseDate DESC
```

The account you want is `Type = Customer` with real opportunities and an activated contract. A
`Prospect` with nothing attached is the decoy.

## 2. Pull opportunities, contract, order

```sql
SELECT Id, Name, StageName, Type, Amount, CloseDate, IsClosed
FROM Opportunity WHERE AccountId = '<acct>' ORDER BY CloseDate DESC

SELECT Id, ContractNumber, Status, StartDate, EndDate, ContractTerm
FROM Contract WHERE AccountId = '<acct>' ORDER BY StartDate DESC

SELECT Id, OrderNumber, Status, EffectiveDate, EndDate, TotalAmount
FROM Order WHERE AccountId = '<acct>' ORDER BY EffectiveDate DESC
```

The **Renewal** opp (stage often "Pending Renewal", type "Renewal..."/"Renewal + Expansion") is the
deal being worked. The **Closed Won** original + the active **Contract** are the current term.

## 3. Pull the line items — this IS the entitlement

```sql
SELECT Opportunity.Name, Product2.Name, Product2.ProductCode, Quantity, UnitPrice, TotalPrice
FROM OpportunityLineItem WHERE Opportunity.AccountId = '<acct>'
ORDER BY Opportunity.CloseDate DESC, TotalPrice DESC

SELECT Product2.Name, Product2.ProductCode, Product2.Family, Quantity, UnitPrice, TotalPrice
FROM OrderItem WHERE OrderId = '<order>' ORDER BY TotalPrice DESC
```

## 4. DECODE THE UNITS (do not skip)

A line quantity is in the SKU's **unit of measure**, not a raw count. Reasoning on the raw number
will invert your conclusions. Pull the product definitions:

```sql
SELECT Name, ProductCode, QuantityUnitOfMeasure, Billable_Metric_Name__c,
       SBQQ__BlockPricingField__c, Pricing_Tier__c, Tier__c, Description
FROM Product2 WHERE ProductCode IN ('<sku1>','<sku2>', ...)
```

Read `QuantityUnitOfMeasure` and `Billable_Metric_Name__c` for each. Real example from a live
Kong Konnect renewal:

| Line shows | UoM | Billable metric | Actually means |
|---|---|---|---|
| API Requests, qty **8** | "API Requests (Millions)" | API Requests | **8 million** requests/yr |
| Services, qty **58** | "Services" | Gateway Service | **58 Gateway Services** |

So "8" looked tiny next to ~26M of actual usage — until decoded, it's an 8M *license* the customer
is running 3-4x over. And "58 Services" vs 29 in use is a half-utilized, expensive line. Neither
story is visible from the raw quantities.

## 5. Value concentration

Multiply out each line. Under per-unit pricing one SKU is usually ~all the ACV (in the example, the
Services line was 99.8% of a $4.59M deal; the API Requests line was $2,291). **The renewal is that
line.** A deck that argues a commercially trivial axis (e.g. request volume on a $2K line) is
arguing the wrong thing, however true the growth is.

Confirm the math reconciles to the opp Amount — it's the integrity check that you decoded correctly:

```
sum(Quantity_i * UnitPrice_i) ≈ Opportunity.Amount
```

## 6. Known gotchas

- **Order vs Opp quantity mismatch.** An Order may show qty 1 of each license item (a partial/PS
  order) while the Opp shows the real quantities. Trust the figure that *reconciles to the deal
  Amount*; flag the other for deal desk to clean up. Don't average them.
- **CPQ subscriptions** (`SBQQ__Subscription__c`) are the cleanest entitlement source when populated,
  but many orgs don't use them — fall back to OpportunityLineItem, which is consistent across the
  Closed Won and Renewal opps.
- **Billable metric ≠ customer's word.** Confirm the contract metric (e.g. "Gateway Service") is the
  same thing the customer counts (e.g. their "managed services") before you build an argument on the
  gap. It usually is, but it's load-bearing — one line to the SE/data owner settles it.

## 7. Who confirms what

| Open item | Owner |
|---|---|
| Exact telemetry source + window behind the measured actuals | The SE/data person who pulled it |
| Billable-metric = customer's term equivalence | Same, or check the product directly |
| Order-vs-Opp quantity anomaly | Deal desk / order ops |
| Pricing model nuance, renewal strategy, intros | Renewal manager |
| Future volumes, go-live dates, new-service plans | The customer |
