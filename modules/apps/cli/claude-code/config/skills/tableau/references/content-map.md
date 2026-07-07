# Content map: Kong's Tableau Cloud site

Surveyed 2026-07-07 via `list-projects` / `list-workbooks` / `list-datasources` /
`search-content` / `get-workbook`. This is a snapshot to save you from
re-discovering the same structure every session -- it drifts over time
(dashboards get added, renamed, deprecated). If something here doesn't match
what the tools return, trust the tools and update this file.

Site: `kong` on `prod-useast-a.online.tableau.com`. 26 projects, 108+
workbooks at survey time. Only CSM-relevant projects are enumerated in
detail below; everything else is listed by name only -- use
`list-workbooks --filter projectName:eq:<name>` to explore those live.

## Kong 360 -- per-account 360 profile

Project id `32bd0076-c9e8-4b1f-9220-737aa0f986fe`. One workbook per topic,
all meant to be looked at for a single named account. This is the project
to reach for when the ask is "what does Tableau say about customer X".

| Workbook | id | Key views |
|---|---|---|
| Kong 360 (original/base) | `8f6c90ce-dc67-4d3e-9270-19eea9064d89` | low usage (14 total views), likely superseded by the others below |
| Kong360 Summary | `b3035d7f-4a7c-451a-b36d-55b2de2bdef9` | Firmographics `f4a50b98-e43d-4eb2-b029-5a37d78c2f46`, Key Contacts `76b6ba40-2cbf-488a-b8f2-68b379cd54e9`, Active Contracts `decf6c23-a522-4588-a6ad-816c02574074` |
| Kong360 Bookings & Opportunities | `cc4292e4-98cd-42b8-aa87-3c3b936098cb` | not yet probed for individual sheet ids |
| Kong360 Consumption | `804d0711-fbc1-4082-ae06-f060021f26ae` | only the "Kong360 Shell" dashboard view was found (`5105f743-...`); no separate data sheet located yet -- check the workbook live with `get-workbook` for any tabs added since |
| Kong360 Churn Risk | `54e0faed-38e1-4861-9d89-b78f59e6a780` | **confirmed working**: `Churn_Risk_Score` `22dcc980-a668-4b15-a6cd-f8faed79bb44` returns real per-account data (see fields below). Also `Churn_Risk_Attributes` `87b7b9e2-f8f8-4aba-80ca-77dad9eb9937`, `Churn_Risk_Comments` `ead788b2-1321-4e65-abf2-34c958b4e1d0` |
| Kong360 Marketing Campaigns | `21ff5029-864e-4cb5-9a35-0ca7f4bb49c7` | not yet probed |
| Kong360 Engagement | `88b0cea1-7a30-41d7-ae8e-aae8f291f077` | not yet probed |
| Kong360 Customer Support | `790ca451-ce75-4434-9c0a-62502199863b` | not yet probed |

**Confirmed fields from `Churn_Risk_Score`** (via `get-view-data`, no
`viewFilters` supplied, returned exactly one row -- see "Row-level security"
below): `CUSTOMER_STAGE__C`, `CXM_SENTIMENT_PICKLIST__C`, `Day of
LAST_GAINSIGHT_TIMELINE_ACTIVITY`, `AVG_CSAT_LAST_6_MONTHS`, `AVG_NPS`,
`ENGAGEMENT_CX_SCORE`, `GATEWAY_API_CALLS_CONSUMPTION`,
`GATEWAY_API_SERVICES_CONSUMPTION`, `HEALTH_SCORE`,
`KONG_ACADEMY_COURSES_COMPLETED`, `OPEN_ESCALATIONS`, `PERCENT_DELIVERED`,
`RENEWAL_EXPANSION_SCORE`, `RENEWAL_RISK_LEVEL_SCORE`, `ROI_SCORE`,
`TOTAL_CASES_LAST_180D`, `TOTAL_HIGH_URG_CASES_LAST_180D`,
`TOTAL_NEW_ACV`, `TOTAL_OPEN_FTIS`.

Backing datasources (both return 403 via `get-datasource-metadata` --
VizQL Data Service is unavailable here, see the main SKILL.md):
- `Kong360_Rollup` -- `088cb8fb-8106-44bc-8f35-ddd74e4c0210`
- `Kong360_Account_ID_Domain_Map` -- `622ba944-fee5-4340-9d95-bd3a7b48b44d`
  (maps an account's web domain to its internal account id -- useful if
  you only have a customer's domain, not their Salesforce/Kong360 id)

`Firmographics` (`f4a50b98-...`) returned HTTP 400 when queried without
filters -- it's likely a dashboard-action/parameter-driven sheet that
needs an account identifier passed via `viewFilters` to render. The exact
filter field name hasn't been confirmed; try the view in a browser once,
note the filter's display name, and use that as the `viewFilters` key.

## Book of Business -- the CSM's own portfolio

Project id `418647c6-e8cf-4578-822b-a2bb261b0d09` (nested under `3.
Production` under `RevOps`). Reach for this when the ask is about "my
accounts" collectively -- pipeline, renewals, usage, PS engagement across
your whole book, not one named customer.

| Workbook | id |
|---|---|
| 0. Book of Business - Homepage | `e819dff5-a3a9-43a9-8b9b-11aab732f70d` |
| 1. Book of Business - Pipeline & Renewals | `15cb65c5-e3ea-4e0a-81a2-2a6d555002d3` |
| 2. Book of Business - Prospecting & Actions | `e4682a8b-d4a0-4703-9de9-62a2652d8801` |
| 3. Book of Business - Product Usage | `53e01fae-8f1c-4eb8-825c-133a37f65c92` |
| 4. Book of Business - PS, Support, & Partner | `5e58effe-c282-496f-8b41-79bbb768c72a` |

**Known gap:** every view checked in "1. Book of Business - Pipeline &
Renewals" (`Closed Bookings` `af8625ff-...`, `Current Quarter Pipeline`
`cb9d00fd-...`, `Renewal Deep Dive` `35f711a2-...`) is `sheetType:
"dashboard"` (confirmed via `search-content`), and `get-view-data` on all
three returned only `"LI button\nbutton\n"` -- nav-button captions, not
the actual pipeline/renewal table. Unlike Kong 360's Churn Risk workbook,
this workbook doesn't appear to publish the underlying worksheets as
separate view tabs. This needs live investigation (e.g. via the
`get-view-image` tool, or asking a site admin whether the underlying
sheets can be exposed) before this project can reliably answer "show me
my renewal pipeline as data".

## Salesforce -- SFDC-sourced dashboards

Project id `b4508a4a-c1f6-49fa-8d12-6938d2e0c59b`. Straightforward SFDC
reporting, not row-level-secured to a single CSM as far as tested.

| Workbook | id |
|---|---|
| Account Tracking | `415241ae-8099-41dc-ba52-63cab72de4d6` |
| Marketing Leads | `85ec05b3-f60e-4fc4-a2fd-58f8c1b4835d` |
| Open Pipeline | `55e67511-8fdd-4e8b-8785-c4416335e97c` |
| Opportunity Overview | `5a8dc27b-2c8c-4698-904b-fa592efb88db` |
| Opportunity Tracking | `97803af3-d709-4147-a941-91b98a603927` |
| Quarterly Sales Result | `a402974e-9bd4-46d3-a4fc-3278aa66f98b` |
| Top Accounts | `630b04fd-430b-4d1c-890b-0d6a67f81f81` |

Datasources: Marketing, Opportunities Account Tracking, Opportunities
Overview, Opportunities Pipeline, Opportunities Qtr Sales, Opportunities
Top Accounts, Opportunities Tracking, Opportunities with Products -- all
in this project, names are self-explanatory, ids not yet captured (use
`list-datasources --filter projectName:eq:Salesforce`).

## 3. Production -- flagship / cross-functional dashboards

Project id `21dd15ca-49f5-4171-9203-7ceaa0ca0b3f` (under RevOps). Houses
`Book of Business` (above) plus:

| Workbook | id | Notes |
|---|---|---|
| Kong Command Center | `856dcbbe-13c4-438e-b6a2-fe5098dfa0e0` | **Site-wide most-used workbook** (21,083 total views, 1,097 in the last month at survey time). Sales/pipeline command center -- Summary, Closed Bookings, Renewal Analysis, Pipeline Generation QTD/YTD Overview, Pipeline Generation Deep Dive, Pipeline Progression, Pipeline Conversions, Forecast Health, AE Forecast Health, AE Weekly Deep Dive, Productivity, Ramping Productivity Deep Dive, Account Penetration, MQL Overview. Skews sales-leadership/AE-productivity, but `Renewal Analysis` and `Account Penetration` are CS-relevant. Backed by `Funnel Metrics Cohort Detail` and `MQL Funnel Conversion Trend` datasources. |
| Account 360 | `1191812c-b476-49e6-be56-05238baab800` | Not yet probed -- name suggests it may overlap with or supersede the "Kong 360" project's per-account workbooks; worth comparing before assuming Kong 360 is the only per-account source. |
| Win Wire | `aaf801e2-7eca-4981-90bb-3d59f2ac8fcf` | Not yet probed |
| Income Revenue | `3e19b196-5b98-44a3-9d3e-252aa8c718e3` | Not yet probed |
| AE 2x2 for QBRs | `837e839c-10f9-49bc-9ebb-d429152343c0` | QBR-prep dashboard, worth checking when prepping a QBR |

## Other projects (not detailed -- use `list-workbooks`/`list-projects` filters live)

- **RevOps** (`520c6ef4-...`) -- parent of "3. Production" and "2. Ad-hoc"
- **Marketing** (`5c3539cb-...`) and subfolders (`1. Marketing KPIs
  (Prod)`, `2. Development`, `2. Ad-hoc`, `3. Data Sources`, `4. Marketing
  - Japan`) -- demand-gen, campaigns, funnel metrics. Not CSM-core but
  useful for "what marketing activity touched this account" questions.
- **Finance** (`27a9ddc1-...`) and subfolders (`0. Resources`, `1.
  Sandbox`, `2. Ad-hoc`, `3. Production`)
- **Professional Services** (`e120398f-...`) and subfolders
  (`Sandbox`/`Production`/`Data Sources`) -- PS delivery/engagement data;
  a `PS Engagement Overview` workbook also turns up oddly in `Samples`.
- **Admin Insights** (`f1fd6796-...`) -- Tableau's own site-governance
  datasources: `TS Events`, `TS Users`, `Site Content`, `Groups`, `Viz
  Load Times`, `Job Performance`, `Permissions`, `Subscriptions`,
  `Tokens`. This is meta-data about the Tableau site itself (who viewed
  what, license usage), not customer data -- only relevant if asked about
  Tableau usage/governance, not CSM work.
- **Samples** -- Tableau's built-in Superstore/Regional sample content.
- **Archive** / **Old / Deprecated Assets** -- deprecated, generally skip
  unless specifically asked for historical content.

## Pulse

`list-all-pulse-metric-definitions` and `list-pulse-metric-subscriptions`
both returned empty at survey time -- no Pulse metrics are currently
published/subscribed for this identity. Don't read that as an error; it's
a genuine "none exist yet" result. Worth re-checking periodically since
Pulse adoption may grow.
