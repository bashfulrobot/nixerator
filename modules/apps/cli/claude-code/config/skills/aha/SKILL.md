---
name: aha
description: >-
  Query and (carefully) update Aha! product-management data via the Aha! REST
  API. Use when the user asks about Aha!, an Aha idea/feature/epic/initiative/
  release/requirement, a reference number like DEVP-123 or PROD-I-42, proxy
  votes/endorsements on ideas, or invokes /aha. Trigger phrases include "look
  up this Aha idea", "what's the status of feature DEVP-123", "search Aha for
  rate-limiting ideas", "add a proxy vote to this idea", "list ideas in the
  portal", "pull the epic from this aha.io link". The skill wraps every call
  in a reproducible script that reads the API token from the AHA_API_TOKEN
  environment variable. Defaults to read-only; any write (create idea, proxy vote, update
  feature) requires explicit per-run confirmation. Do NOT trigger on tangential
  mentions of Aha, and do NOT author feature-request documents here -- the
  feature-request skill owns that; this skill is the API layer it can call.
---

# Aha! REST API (aha)

Work with Aha! through its v1 REST API via `scripts/aha.sh`. The script reads
the API token from the `AHA_API_TOKEN` environment variable and carries no
dependency on any particular secrets tool, so it's portable and safe to share.
Default posture is read-only; writes need confirmation.

## Why this skill exists

Aha! is the source of truth for Kong product management: features, epics,
initiatives, releases, and the customer-facing idea portal. As a CSM you mostly
*read* it -- "what's the status of DEVP-123", "is there already an idea for X",
"how many endorsements does this have" -- and occasionally *write* to it:
logging a proxy vote on a customer's behalf, or creating an idea. A wrong write
is visible to the whole product org and sometimes to customers (the portal), so
writes go through a confirmation step. Reads are free.

The token is supplied via the `AHA_API_TOKEN` environment variable. Keeping the
secret-provisioning out of the script -- rather than hardcoding a vault path --
is deliberate: it makes the skill reproducible, auditable, and portable enough
to share with someone who manages their secrets differently.

## Prerequisites

- `AHA_API_TOKEN` set in the environment -- an Aha! API key (generate one at
  `https://secure.aha.io/settings/api_keys`). Provide it however you manage
  secrets: a shell export, a `.env` you source, a CI secret, or a secrets
  manager. The script intentionally doesn't reach into any vault itself, which
  keeps it portable and shareable.
- `curl` and `jq` on PATH.
- Default account is `konghq.aha.io`. Override with `AHA_SUBDOMAIN=otherco`.

## The one tool: scripts/aha.sh

Every endpoint goes through the same wrapper. You pass an HTTP method and a path
relative to `/api/v1/`; it adds auth, encodes query params, and pretty-prints
JSON.

```bash
# Read a single record by reference number
bash scripts/aha.sh get features/DEVP-123
bash scripts/aha.sh get epics/DEVP-E-8
bash scripts/aha.sh get ideas/PROD-I-42

# List / search (note: list endpoints are scoped to a product)
bash scripts/aha.sh get products/DEVP/ideas -q 'q=rate limiting' -q per_page=50
bash scripts/aha.sh get products/DEVP/features --paginate -q 'updated_since=2026-01-01'

# Trim the payload to the fields you need (faster, easier to read)
bash scripts/aha.sh get ideas/PROD-I-42 -q 'fields=reference_num,name,workflow_status,endorsements_count'

# Write (see the writes playbook below first) -- proxy vote = endorsement
# email = the Kong submitter logging the vote, NOT the customer (always dustin.krysak@konghq.com for this user); the account is set by idea_organization_id
bash scripts/aha.sh post ideas/PROD-I-42/endorsements -d '{"idea_endorsement":{"email":"dustin.krysak@konghq.com","idea_organization_id":7210570342900669490,"value":25000}}'
```

Key flags: `-q KEY=VALUE` (repeatable query params, values auto-encoded),
`-d JSON` or `-d @file.json` (request body), `--paginate` (follow every page and
merge the collection into one flat JSON array, GET only), `--per-page N`,
`--raw`, `--status`. Run `bash scripts/aha.sh --help` for the full list.

For the endpoint catalogue, query params, pagination, rate limits, and field
selection, read `references/api-reference.md`. For ready-made recipes (search
ideas, create an idea, log a proxy vote, find features by initiative, walk an
epic's children), read `references/recipes.md`.

## Workflow

### Step 1: Classify the request

- **Read** -- GET anything. Safe; proceed. This is ~90% of requests.
- **Write** -- POST/PUT/PATCH/DELETE (create idea, proxy vote, update a record).
  Stop and follow the writes playbook below.

### Step 2 (reads): Resolve the identifier, then fetch

If the user gives a reference number (`DEVP-123`, `DEVP-E-8`, `PROD-I-42`) or an
aha.io URL, extract the reference and GET it directly -- you do not need the
internal id. The reference prefix tells you the type:

- `<PREFIX>-<n>` -> a feature (e.g. `DEVP-123`)
- `<PREFIX>-E-<n>` -> an epic (e.g. `DEVP-E-8`)
- `<PREFIX>-I-<n>` -> an idea (e.g. `DEVP-I-42`)
- `<PREFIX>-R-<n>` -> a requirement; `<PREFIX>-<n>` releases vary

If you only have a search term, list within the product:
`get products/<PREFIX>/ideas -q 'q=<term>'`. Default to `fields=` selection so
responses stay small, and `--paginate` only when the user actually wants the
whole set (it can be many pages -- see the rate-limit note in the reference).

### Step 3 (writes): Confirm before mutating

Aha writes are visible org-wide and sometimes customer-facing (the portal).
Before any POST/PUT/PATCH/DELETE:

1. Show the user the exact call you intend to run: method, full path, and the
   JSON body, with the target account (`konghq.aha.io`) stated explicitly.
2. For a proxy vote, confirm the idea reference, the customer org, the
   submitting Kong user's email (the vote is logged by a Kong employee on behalf
   of the account, so `email` is the Kong submitter's address, never the
   customer's), and the value -- a wrong value skews prioritization. See the
   proxy vote recipe in `references/recipes.md`. For this user, the submitter
   email is always `dustin.krysak@konghq.com`; the `AHA_API_TOKEN` belongs to
   that same account, so proxy votes and comments are attributed to Dustin
   regardless. Still confirm the org and value before posting.
3. Get an explicit "yes" for *this* call. Approval of one write is not approval
   of the next.
4. Run it, then GET the record back to confirm the change landed.

Do not batch multiple writes behind a single confirmation. One call, one yes.

## Caching: identifiers and slow metadata

Two layers. Use the `skill-cache` warm-cache CLI for the stable identifiers you
re-resolve on most runs; use native auto-memory for softer, contextual facts.

### skill-cache (stable identifiers)

Before resolving a customer name to its Aha idea-organization id, or a product
name to its reference prefix, check the cache first:

```bash
skill-cache get aha customers "<name>"   # -> {"org_id":"ACCOUNT-O-32404"} or non-zero on miss
skill-cache get aha products  "<name>"   # -> {"ref_prefix":"DEVP"} or miss
```

On a hit, use the value -- no API call. On a miss, resolve via the API
(`idea_organizations -q 'q=<name>'` for the org; the product list for a prefix),
then write it back:

```bash
skill-cache put aha customers "<name>" '{"org_id":"ACCOUNT-O-32404"}' --alias "<short name>"
skill-cache put aha products  "<name>" '{"ref_prefix":"DEVP"}'
```

When a customer's org id is cached, pass it straight to the pull-and-assess
script to skip the search: `scripts/customer-ideas.sh --org ACCOUNT-O-32404`.

Cache only stable identity -- org ids, ref prefixes, custom-field API keys (no
`--ttl`). **Never cache idea status, endorsement counts, or vote weights**;
those are the volatile fields you query live. If a cached id looks wrong,
`skill-cache forget aha customers "<name>"` and re-resolve. Full convention:
`.claude/docs/skill-cache.md`.

### auto-memory (soft facts)

Use Claude Code's native auto-memory for things that aren't a clean key->id
mapping: workflow-status names that differ from the defaults, named records the
user refers to ("the gateway initiative"), and Kong-Aha schema gotchas. Recall
before acting; store what's reusable after. Not reusable: one-off query
results, transient ids.

## Per-customer FR dashboards (Sheet + PDF)

For "build/refresh <customer>'s FR dashboard", "update the feature request
sheet for X", or "send me a PDF of X's feature requests": don't reimplement
this here. Use the `aha-fr-report` package deployed via nixerator
(`~/git/nixerator/modules/apps/cli/aha-fr-report/`), installed on PATH on
this workstation. qbert also runs it daily on a systemd user timer (09:30):

```bash
aha-fr-report-one "HealthEquity"   # one customer, on demand
aha-fr-report                      # every customer in customers.txt
```

This writes an internal Google Sheet into `<Customer>/CS/FRs/` in Kong's
"Customers" shared drive (reused across runs, same link every time) and a
Kong-branded PDF snapshot into `<Customer>/CS/FRs/Customer-PDF-Reports/`. That shared
drive enforces `domainUsersOnly` (verified live against the API), so the PDF
is not itself externally link-shareable -- download it and attach to an
email or Slack message to actually get it to the customer. Both commands
print the Sheet URL and the PDF's Drive link when done.

If the command isn't found, nixerator hasn't been rebuilt on this host yet
(`apps.cli.aha-fr-report.enable = true` in the relevant host's
`modules.nix`, activated via `just rebuild`). To add a new customer to the
daily qbert run, add a line to
`~/git/nixerator/modules/apps/cli/aha-fr-report/customers.txt` and rebuild.

## What NOT to do

- Do not hardcode or echo the API token. The script reads it from
  `AHA_API_TOKEN`; never paste the raw token into a command or commit it.
- Do not run a write without showing the call and getting a yes for it.
- Do not `--paginate` a huge collection just to grab the first few records --
  use `-q per_page=N` and read page 1. Aha allows 300 req/min; runaway
  pagination burns the budget and returns 429s.
- Do not invent endpoint paths, custom-field keys, or query params. If unsure,
  check `references/api-reference.md` or GET one record and inspect its fields.
- Do not author or format a feature-request write-up here. That belongs to the
  feature-request skill; this skill is just the API it calls.

## Files in this skill

### scripts/
- `aha.sh` -- the API wrapper. Auth from `AHA_API_TOKEN`, query encoding, body
  from inline JSON or `@file`, `--paginate` collection merge, jq pretty-printing.

### references/
- `api-reference.md` -- base URL, auth, the resource/endpoint catalogue, query
  params, pagination, rate limits, and `fields=` selection.
- `recipes.md` -- copy-paste workflows for the common CSM tasks.
