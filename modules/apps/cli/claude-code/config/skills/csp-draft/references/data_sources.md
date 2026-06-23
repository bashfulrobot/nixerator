# CSP Data Sources — Salesforce & Snowflake/Clari

This reference governs how the CSP skill gathers enrichment data from Salesforce and Snowflake
before GOSIM extraction. Read this file during **Step 1.5** of the skill workflow.

---

## Connector Check (do this first)

Before issuing any queries, verify both connectors are available in your tool list:
- **Salesforce MCP connector** — for account, opportunity, and line item data
- **Snowflake MCP connector** — for Clari transcript searches and account health data

If either is missing, tell the CSM:

> "To auto-enrich the CSP I need two connectors enabled:
> 1. **Salesforce** — for account contacts, products, and sales context
> 2. **Snowflake** — for Clari call transcripts and account health data
>
> It looks like [Salesforce / Snowflake / both] isn't connected yet. You can enable it
> in the **MCP Apps** section of your Claude settings. Once connected, come back and
> I'll pull the enrichment data automatically.
>
> In the meantime, I can still build the CSP from the inputs you've provided — I just
> won't be able to pre-fill fields from Salesforce or call transcripts."

Unlike the handover skill, missing connectors are **not a hard stop** — the CSP skill can
proceed with manual inputs. Note what's unavailable and continue.

---

## Transcript Input — Three Paths

Detect which path applies at the start of Step 0. Priority order: Path A → Path B → Path C.

### Path A — Direct Transcript Paste (highest priority)
**Trigger**: The CSM has pasted raw transcript text into the conversation.
**Action**: Use the transcript directly as a [SOURCED] input in GOSIM extraction.
No Snowflake query needed for transcripts — skip the Clari calls in Step 1.5 and go
straight to Salesforce enrichment only.
**Confidence**: [SOURCED] — treat content from the transcript as directly stated by the customer.

### Path B — Specific Clari Call URL
**Trigger**: The CSM provides a Clari URL like `https://copilot.clari.com/call/{call_id}`.
**Action**: Extract the call ID from the URL and query Snowflake for that specific transcript:

```sql
-- Via Snowflake:sql_exec_tool
SELECT CALL_DATE, ATTENDEES, FULL_TRANSCRIPT_TEXT
FROM REVANALYTICS.CLARI.CLARI_CALLS_RAW
WHERE CALL_ID = '{call_id}'
LIMIT 1
```

If `FULL_TRANSCRIPT_TEXT` is unavailable, try `TRANSCRIPT_TEXT` or query via the CSM agent:
> "Retrieve the full transcript for Clari call ID {call_id} on account {account_name}."

**Confidence**: [SOURCED] — specific call, specific context.

### Path C — 6-Month Account Search (fallback)
**Trigger**: No transcript provided and no Clari URL given.
**Action**: Query Snowflake across all calls for this account in the last 6 months.
Uses 3 clustered queries (see Snowflake section below).
**Confidence**: [VERIFY] — synthesized across calls; CSM should confirm relevance.

---

## Required Input: Salesforce Account URL

The skill requires a Salesforce Account URL to run enrichment. If the CSM hasn't provided one,
ask:

> "To pull your Salesforce data and Clari transcripts automatically, I need the Salesforce
> Account URL for this customer. You can find it by opening the account in Salesforce and
> copying the URL — it looks like:
> `https://kong.lightning.force.com/lightning/r/Account/001.../view`"

Extract the 18-character Account ID (e.g. `001PJ00000XYZ1234`) from the URL and use it in
all subsequent queries.

---

## Salesforce Queries

Run these in the order shown. Total budget: **3 tool calls**.

**Known field name gotchas (from production — do not deviate):**
- `Owner.Name` → does NOT work. Use `Opportunity_Owner_Name__c`
- `Champion__c` → does NOT exist. Use `Champion_Name__c`
- `Incumbents__c` → does NOT exist. Use `Incumbents_Kong__c`
- `AE_Current_State__c` → does NOT exist. Use `XDR_Current_State_Challenges__c`
- If a query errors: read the error, drop the offending field, move on. Zero retries.

### SF Call 1 — Account Core Fields

```sql
SELECT Id, Name,
  CXM_Name__c,
  Internal_Slack_Channel__c,
  External_Slack_Channel__c,
  Account_Plan__c,
  Google_Drive_Folder__c,
  Org_Chart_Link__c
FROM Account
WHERE Id = '{account_id}'
```

### SF Call 2 — Most Recent Closed-Won Opportunity

This surfaces sales context — what was promised, what value drivers were captured,
what the customer said they wanted to achieve.

```sql
SELECT Id, Name,
  Opportunity_Owner_Name__c,
  StageName, CloseDate,
  ACV__c, New_ACV__c, TCV__c,
  ContractTerminmonths__c,
  XDR_Current_State_Challenges__c,
  Value_Drivers__c,
  Positive_Business_Outcomes__c,
  Why_Now__c,
  Requirements_Success_Metrics__c,
  Metrics__c,
  Decision_Criteria__c,
  Champion_Name__c,
  Economic_Buyer__c,
  Main_Competitor_s__c,
  Incumbents_Kong__c,
  Sales_Play__c,
  Use_Case__c
FROM Opportunity
WHERE AccountId = '{account_id}'
  AND StageName = 'Closed Won'
ORDER BY CloseDate DESC
LIMIT 1
```

### SF Call 3 — Products Purchased (Line Items)

```sql
SELECT Product2.Name, ACV__c, TCV__c, Quantity,
  ServiceDate, EndDate
FROM OpportunityLineItem
WHERE OpportunityId = '{opportunity_id_from_call_2}'
ORDER BY ACV__c DESC
```

---

## Salesforce Field → GOSIM Mapping

Use this table when extracting GOSIM content from Salesforce data in Step 2.

| Salesforce Field | GOSIM Layer | Confidence | Notes |
|---|---|---|---|
| `XDR_Current_State_Challenges__c` | G (context) + O | [VERIFY] | AE-captured current state — good for Goal context conversation prep and validating Objective urgency |
| `Value_Drivers__c` | O | [VERIFY] | Identifies which of the 4 drivers are active — cross-reference with `value_drivers.md` |
| `Positive_Business_Outcomes__c` | O | [VERIFY] | AE's version of desired outcomes — good Objective language to validate with customer |
| `Why_Now__c` | G (context) | [VERIFY] | Urgency language — useful for Goal narrative and exec conversation prep |
| `Requirements_Success_Metrics__c` + `Metrics__c` | M | [VERIFY] | Pre-populates Metrics — needs baseline, target, owner, cadence confirmed |
| `Decision_Criteria__c` | S | [VERIFY] | May contain vendor-neutral architectural decisions — check for Strategy candidates |
| `Champion_Name__c` | Champion (L1 footer) | [SOURCED] | Direct field — use as-is |
| `Economic_Buyer__c` | Champion (context) | [SOURCED] | Useful for stakeholder mapping |
| `Sales_Play__c` + `Use_Case__c` | O + I | [VERIFY] | Confirms active value driver and likely Initiative scope |
| `Main_Competitor_s__c` + `Incumbents_Kong__c` | S (context) | [VERIFY] | Signals current-state architecture — informs Strategy layer |
| `OpportunityLineItems` (products) | I | [SOURCED] | What's contracted = baseline Initiatives — these are confirmed, not hypothetical |
| `ContractTerminmonths__c` + `ServiceDate` + `EndDate` | M (cadence context) | [SOURCED] | Informs CSP review cadence and renewal timeline |
| `CXM_Name__c` (Account) | CSM (L1 footer) | [SOURCED] | Confirms assigned CSM |

---

## Snowflake / Clari Queries (Path C — 6-Month Account Search)

Use the **Snowflake:CSM** agent for account-level transcript searches. This agent has access
to `TRANSCRIPT_UTTERANCE_SEARCH` scoped to account context.

Run 3 clustered queries. Each cluster groups semantically related GOSIM topics to keep
searches focused and fast. Include the account name in every query.

**Time window**: All queries filter to the last 6 months. Include this instruction in every
agent query: *"Limit your search to calls from the last 6 months only."*

### Snowflake Call 1 — Goal & Context Cluster

> "For the account **{Company Name}**, search call transcripts from the **last 6 months** and
> answer the following. Label each answer with its number. If a topic wasn't discussed in
> calls, say 'Not discussed in calls'. Include the call date and Clari call URL for any
> calls you reference.
>
> 1. STRATEGIC DIRECTION: What has the customer's leadership or exec sponsor said about where
>    the company or their department is headed? What are their stated priorities or goals?
> 2. DEPARTMENTAL GOAL: What has the Head of Platform, CTO, CISO, or VP Engineering said
>    their team is specifically trying to achieve? How do they describe their own north star?
> 3. CURRENT STATE PAIN: What current state challenges, frustrations, or problems have they
>    described? What's not working today?"

Maps to: **G** (context + conversation prep), Goal [VERIFY]

### Snowflake Call 2 — Objectives & Metrics Cluster

> "For the account **{Company Name}**, search call transcripts from the **last 6 months** and
> answer the following. Label each answer with its number. If a topic wasn't discussed in
> calls, say 'Not discussed in calls'. Include the call date and Clari call URL for any
> calls you reference.
>
> 4. DESIRED OUTCOMES: What specific outcomes or results has the customer said they want to
>    achieve? What does success look like to them?
> 5. METRICS & TARGETS: Have any specific numbers, targets, baselines, or success metrics
>    been discussed? Any before/after comparisons or KPIs mentioned?
> 6. TIMELINES & DEADLINES: Have any specific dates, deadlines, or urgency drivers been
>    discussed? Any hard dates they've committed to?"

Maps to: **O** + **M**, [VERIFY]

### Snowflake Call 3 — Strategy, Initiatives & Risk Cluster

> "For the account **{Company Name}**, search call transcripts from the **last 6 months** and
> answer the following. Label each answer with its number. If a topic wasn't discussed in
> calls, say 'Not discussed in calls'. Include the call date and Clari call URL for any
> calls you reference.
>
> 7. ARCHITECTURE & STRATEGY: What technology or architecture decisions has the customer
>    discussed? Platform model, cloud strategy, centralized vs. federated, build vs. buy?
> 8. KONG USAGE & EXPANSION: How are they currently using Kong? What products or teams
>    have they discussed expanding to? Any roadmap or future state discussions?
> 9. RISKS & CONCERNS: What concerns, blockers, objections, or risks have been raised?
>    Any dissatisfaction or friction discussed?"

Maps to: **S** + **I** + Gaps, [VERIFY]

### Fallback — Direct SQL (if CSM agent returns nothing)

If the CSM agent returns no results, fall back to direct SQL:

```sql
-- Via Snowflake:sql_exec_tool
SELECT CALL_DATE, CALL_DURATION_MINUTES,
  ATTENDEES, CALL_REVIEW_PAGE_URL,
  LEFT(TRANSCRIPT_TEXT, 5000) AS TRANSCRIPT_EXCERPT
FROM REVANALYTICS.CLARI.CLARI_CALLS_RAW
WHERE ACCOUNT_NAME ILIKE '%{company_name}%'
  AND CALL_DATE >= DATEADD(month, -6, CURRENT_DATE())
ORDER BY CALL_DATE DESC
LIMIT 10
```

Summarize the returned excerpts manually against the GOSIM topic clusters above.

---

## Snowflake Account Health Query

Run this alongside the transcript queries (can be combined into a single tool call if supported):

```sql
-- Via Snowflake:sql_exec_tool
SELECT
  ACCOUNT_NAME,
  HEALTH_SCORE,
  HEALTH_SCORE_TREND,
  ACTIVE_KONNECT_SERVICES_Y1, ACTIVE_KONNECT_SERVICES_ACV,
  ACTIVE_KONNECT_API_CALL_Y1, ACTIVE_KONNECT_API_CALL_ACV,
  ACTIVE_KONNECT_AI_GATEWAY_Y1, ACTIVE_KONNECT_AI_GATEWAY_ACV,
  ACTIVE_MESH_Y1, ACTIVE_MESH_ACV,
  ACTIVE_DCG_Y1, ACTIVE_DCG_ACV,
  ACTIVE_INSOMNIA_Y1, ACTIVE_INSOMNIA_ACV,
  ACTIVE_KONNECT_CATALOG_Y1, ACTIVE_KONNECT_CATALOG_ACV
FROM REVANALYTICS.CX.V_AI_HEALTH_SUMMARIES
WHERE ACCOUNT_ID = '{account_id}'
  AND INFORMATION_TYPE = 'health_summary'
LIMIT 1
```

Maps to: **I** baseline (what's active), **M** (usage as a baseline metric proxy), CSP header context.

---

## Confidence Rules Summary

| Source | Confidence | Rationale |
|---|---|---|
| Pasted transcript (Path A) | [SOURCED] | Direct customer language, just captured |
| Specific Clari call (Path B) | [SOURCED] | Specific call, known context |
| 6-month Clari search (Path C) | [VERIFY] | Synthesized across calls — CSM confirms |
| SF hard data (ACV, products, dates, champion) | [SOURCED] | Structured fields, directly entered |
| SF qualitative fields (challenges, outcomes, value drivers) | [VERIFY] | AE-captured — may be outdated or paraphrased |
| Web research (company strategy) | Context only | Never the CSP Goal — used for conversation prep |

---

## Total Tool Call Budget for Step 1.5

| Call | Source | Content |
|---|---|---|
| 1 | Salesforce | Account core fields |
| 2 | Salesforce | Most recent Closed-Won opportunity |
| 3 | Salesforce | Line items (products) |
| 4 | Snowflake | Account health summary |
| 5 | Snowflake:CSM | Transcript Cluster 1 — Goal & Context |
| 6 | Snowflake:CSM | Transcript Cluster 2 — Objectives & Metrics |
| 7 | Snowflake:CSM | Transcript Cluster 3 — Strategy, Initiatives & Risk |

**Maximum 7 calls.** If a call fails, take what you have and move on — a partial enrichment
is always better than a timeout. Write `—` for any field that couldn't be populated.

If Path A or B is in use (transcript already provided), skip calls 5–7 and stay within a
4-call budget for Salesforce + health data.
