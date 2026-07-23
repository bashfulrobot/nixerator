---
name: tableau
description: >-
  Query Kong's Tableau Cloud site via the local `@tableau/mcp-server` MCP
  tools (list-projects, list-workbooks, list-datasources, search-content,
  get-workbook, get-view, get-view-data, query-datasource, Pulse metric
  tools, and more). Use this whenever the user asks about Tableau,
  dashboards, or reports on the Kong site -- especially customer health
  score, renewal risk, consumption/usage, churn risk, NPS/CSAT, bookings,
  or pipeline data pulled from Tableau. Also trigger for "Account 360",
  "Kong 360", "book of business", "pull up the churn risk dashboard",
  "what's this account's health score in Tableau", "check the renewal
  pipeline", "Kong Command Center", "active contract", "Konnect
  subscription usage", "Konnect capacity consumption", or any request to
  list/search/export a Tableau
  workbook, view, or data source, even if the user doesn't say the word
  "Tableau" explicitly but clearly means the CS/RevOps reporting site
  (e.g. "what does the dashboard say about Acme's renewal risk"). Do NOT
  trigger for Salesforce/SFDC queries that don't reference Tableau
  reporting (the `sfdc` skill owns those) or for building new success-plan
  documents (the `kong-success-plan` skill owns that, though it may call
  into this skill for data).
---

# Tableau (Kong's Tableau Cloud)

Pull data out of Kong's Tableau Cloud site for CSM work: customer health
scores, renewal risk, consumption, churn signals, pipeline, and the
broader RevOps/Marketing/Finance content that happens to live on the same
site. The MCP tools give you the primitives (list, search, describe,
query, export); this skill is the map and the operating manual for using
them against *this* site without wasting calls rediscovering things or
tripping over its quirks.

## Why this skill exists

The Tableau MCP server is generic -- it doesn't know that this site's
VizQL Data Service is unreachable, that half its "views" are
button-driven dashboard shells rather than data tables, or that firing
two tool calls at once produces a spurious 401. Knowing that upfront is
the difference between three tool calls and fifteen.

## Environment

Self-hosted MCP server (`@tableau/mcp-server@2.22.0`, pinned) configured
in `modules/apps/cli/claude-code/cfg/mcp-servers.nix`, run locally via
`npx`, authenticated with a Personal Access Token from the 1Password item
`Tableau-PAT` (vault `nixerator`). Site: `kong` on
`prod-useast-a.online.tableau.com`. Admin tools are intentionally
disabled (`ADMIN_TOOLS_ENABLED` unset) -- there is no delete-workbook or
delete-datasource available, and you shouldn't look for a workaround if
asked to delete something; tell the user it's disabled by design.

Never attempt to read the `Tableau-PAT` item's field values (hostname,
site name, username, credential) via 1Password -- the MCP server already
has them wired through its env. Reading rendered secret values is a hard
boundary regardless of how innocuous the field looks.

## Operating rules (read before making calls)

These came from directly probing the site's behavior, not from Tableau's
general docs -- they're specific to how this server and site respond.

**1. Call tools one at a time.** Firing multiple Tableau MCP tool calls
in the same turn reliably produces spurious `401` or `429` errors on some
of them, even though the same calls succeed individually seconds later.
If a call fails with `401` or `429`, retry it alone before concluding
it's a real auth or permission problem -- in practice, a solo retry
almost always succeeds. Only escalate ("this PAT may need rotating") if a
solo, unhurried retry also fails.

**2. The VizQL Data Service is unavailable on this site.**
`get-datasource-metadata` and `query-datasource` return `403` for every
datasource tested, including Tableau's own bundled Superstore sample --
so this isn't a per-datasource permission issue, it's the whole service.
Don't spend calls trying different datasources hoping one works. For
real data, use `get-view-data` against a published *view* instead (see
rule 3) -- it returns the same underlying numbers as CSV, just scoped to
whatever a dashboard already renders rather than an arbitrary query.

**3. Distinguish dashboard views from sheet views before calling
`get-view-data`.** A workbook's published "views" are a mix of
dashboards (interactive containers, often literally named "Shell" or
built around nav buttons) and individual worksheets/sheets (the actual
charts/tables). `get-view-data` on a dashboard-type view frequently
returns nonsense like `"LI button\nbutton\n"` -- the caption of whatever
object happens to be primary, not the chart you wanted. `get-view-data`
on a genuine sheet-type view returns real rows. Before pulling data from
an unfamiliar view: run `search-content` filtered to `contentTypes:
["view"]` and check the `sheetType` field (`"dashboard"` vs. an actual
worksheet), or just try it and treat "returns a couple of button-caption
words" as a signal to look for a different, more specific sheet in the
same workbook. `references/content-map.md` already tells you which views
are confirmed to return real data vs. confirmed dashboard shells for the
Kong 360 and Book of Business workbooks.

**4. A 400 on a specific sheet usually means it needs an account
identifier -- and for Account 360, that's the `Account ID Parameter`
Tableau Parameter, not an `Account Name` data filter.** Some sheets (e.g.
`Firmographics` in Kong360 Summary) are driven by a dashboard action or
parameter and won't render standalone. The `Account 360` workbook (see
the content map) uses one global control across all its tabs -- **a
Tableau Parameter named `Account ID Parameter`, which takes the raw SFDC
Account ID**, confirmed from a live dashboard URL
(`?Account%20ID%20Parameter=<id>`) and verified end-to-end against a real
account (returned data included the account name and a known contact
verbatim). Pass it the same way as a regular filter --
`viewFilters: {"Account ID Parameter": "<SFDC Account ID>"}` -- the
MCP tool doesn't distinguish parameters from filters. **`Account Name`
does NOT work here** -- every attempt with real name variants or the
SFDC Account ID under that key returned zero rows; an earlier version of
this doc claimed otherwise based on a false-positive test (a nonexistent
value also returned zero, but because the account wasn't in scope under
that key, not because the field caption was right). If `Account ID
Parameter` doesn't resolve the account you need, get the live dashboard
URL from the user or the Tableau UI and read the actual parameter/filter
name off the query string rather than guessing at more field-name
variants -- `SFDC Account ID`, `Domain`, and `Konnect Organization ID`
mentioned in the companion doc as alternative UI filter options are
unverified via the API and may have the same parameter-vs-filter trap.

**5. Row-level security scopes some content to the querying identity --
and on Kong360 Churn Risk, it isn't overridable at all.** `Churn_Risk_Score`,
`Churn_Risk_Attributes`, and `Churn_Risk_Comments` in Kong360 Churn Risk
return exactly one row -- the account tied to whoever the PAT belongs to
-- regardless of what you pass as `Account Name`: a real value, a made-up
nonexistent value, and no filter at all all return byte-identical output.
Verify this with a nonexistent-value test before trusting a non-empty
result from these three views as being about the account you asked for.
Assume "Book of Business" and similar my-portfolio dashboards behave
similarly (RLS-scoped), though Account 360's `Account ID Parameter` (rule
4) *does* successfully override the default for a different named
account -- so RLS-scoping and "filter doesn't work" aren't the same
failure mode, and it's worth testing which one you're hitting. If you
need another CSM's book, that's a different credential, not a different
query.

**6. "No X found" from Pulse tools can mean genuine absence, not an
error.** `list-all-pulse-metric-definitions` and
`list-pulse-metric-subscriptions` return a friendly "none found" message
rather than surfacing HTTP status codes -- so an empty Pulse result isn't
necessarily masking an auth failure the way it might look. Confirmed by
cross-checking against a working call (`list-projects`) succeeding in the
same session.

## Content map

`references/content-map.md` has the project/workbook/view/datasource
inventory as of the last survey, with confirmed-working view ids for
Account 360, Kong 360 (Churn Risk), and known gaps for Book of Business
(Pipeline & Renewals). Read it before falling back to
`list-projects`/`list-workbooks` from scratch -- it'll usually get you
straight to the right workbook id. It's a snapshot, not a live source of
truth: if something's missing or renamed, the tools are still
authoritative, and it's worth updating the file once you've confirmed the
change.

Some dashboards have a companion Google Doc explaining what each tab
means (the content map links the one for Account 360). These usually
require Kong Workspace auth that a plain fetch won't have -- use the
Google Drive MCP tools (`read_file_content` with the doc's file id,
extracted from its URL) rather than a generic web fetch, which will 401.

## Workflow

### Step 1: Classify the request

- **A specific customer's account health/renewal/consumption/churn/
  contracts/support/PS engagement** -> the **Account 360** workbook
  (`references/content-map.md`) is the primary, actively-maintained
  source -- start there. It's one workbook, one global control
  (`viewFilters: {"Account ID Parameter": "<SFDC Account ID>"}`, a
  Tableau Parameter, confirmed working -- see rule 4; `Account Name`
  does NOT work), and one tab per topic (Active Contract, Bookings &
  Opportunities, Konnect Subscription, Konnect Plus, Kong Enterprise
  On-Prem, Konnect Capacity Consumption, Account Engagement, Support,
  Customer Health & Risks, Professional Services). Only fall back to the
  older "Kong 360" project if Account 360 doesn't cover what was asked
  (it has no direct equivalent for Marketing Campaigns or Engagement).
- **"My" pipeline/renewals/usage/prospecting across the whole book** ->
  Book of Business project. Be aware of the known gap noted in the
  content map (the Pipeline & Renewals views haven't yielded real tabular
  data yet) -- if `get-view-data` returns button captions, try
  `get-view-image` for a visual read instead, or ask the user whether
  they know of a specific underlying worksheet name.
- **Anything else on the site** -- ad-hoc report, unfamiliar workbook,
  cross-team dashboard -- treat it like the general path below.

### Step 2 (unfamiliar content): discover, then pull

If the content map doesn't already have what you need:

1. `search-content` with relevant terms (fastest way to find a workbook/
   view/datasource by name across the whole site, and it tells you
   `sheetType` up front).
2. `get-workbook` on the workbook id to see its full view list.
3. `get-view` on a candidate view id for its metadata (owner, project,
   usage stats) if you need to confirm you have the right one before
   pulling data.
4. `get-view-data` on the sheet-type view id to get the actual rows. Pass
   `viewFilters` if the view is parameter-driven (rule 4).

Don't reach for `get-datasource-metadata` or `query-datasource` first --
they're dead ends on this site (rule 2). If a future session finds they
do work (e.g. after a site admin enables the Metadata API), update rule 2
and start using them; they'd be a cleaner path than reverse-engineering
view filters.

### Step 3: Present the data

Default to a plain table or a short narrative summary of the pulled
numbers -- whichever fits what was asked. If the user wants this rolled
into a document (a success plan, a QBR deck, a renewal projection), that
belongs to a different skill (`kong-success-plan`, `renewal-projection`)
-- pull the data here, hand it off there.

## Memory

Same two-layer split as the `sfdc` skill.

### skill-cache (stable identifiers)

Before re-running `list-workbooks`/`list-views` to resolve a name to an
id, check the cache:

```bash
skill-cache get tableau workbooks "<workbook name>"     # -> {"id":"..."}
skill-cache get tableau views     "<workbook>/<view>"   # -> {"id":"..."}
skill-cache get tableau datasources "<datasource name>" # -> {"id":"..."}
```

On a hit, use it. On a miss, resolve via the tools (or the content map),
then write back -- no `--ttl`, these ids are effectively permanent:

```bash
skill-cache put tableau workbooks "Kong360 Churn Risk" '{"id":"54e0faed-38e1-4861-9d89-b78f59e6a780"}'
skill-cache put tableau views "Kong360 Churn Risk/Churn_Risk_Score" '{"id":"22dcc980-a668-4b15-a6cd-f8faed79bb44"}'
```

Never cache query *results* or field values -- only stable ids. Full
convention: `.claude/docs/skill-cache.md`.

### auto-memory (soft facts)

Save the things that took real digging to learn and would otherwise be
rediscovered the hard way: a `viewFilters` field name that turned out to
work, which workbook actually holds a given metric once verified live,
row-level-security surprises, or any correction to something this skill
currently gets wrong. Don't save one-off query results or task-specific
numbers -- those belong to the conversation, not to memory.

## What NOT to do

- Don't fire Tableau MCP tool calls in parallel -- see rule 1. Sequential
  and slightly slower beats fast and flaky.
- Don't treat a single 401/429 as proof the PAT is broken -- retry alone
  first (rule 1).
- Don't call `get-datasource-metadata`/`query-datasource` expecting them
  to work -- they don't, site-wide (rule 2).
- Don't trust `get-view-data` output on a dashboard-type view at face
  value -- if it looks like a caption fragment rather than a data table,
  it probably is one (rule 3).
- Don't invent a `viewFilters` field name -- confirm it (via the browser
  or a 400's error detail if present) before assuming it worked.
- Don't expect to see accounts outside the querying identity's own book
  from row-level-secured views (rule 5) -- that's not a bug to work
  around.
- Don't try to route around the disabled admin tools (delete-*, Admin
  Insights query group) -- they're off by design.

## Files in this skill

### references/

- `content-map.md` -- project/workbook/view/datasource inventory with
  ids, confirmed-working vs. confirmed-broken views, and open questions
  from the last live survey.
