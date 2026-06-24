# Aha! recipes

Copy-paste workflows for the common CSM tasks. All commands assume you're in the
skill directory (`~/.claude/skills/aha`) so `scripts/aha.sh` resolves; from
elsewhere, use the absolute path. Replace `DEVP` with the relevant product key.

## Read a record from a reference number or URL

A user pastes `DEVP-E-8` or `https://konghq.aha.io/epics/DEVP-E-8`. Strip to the
reference and GET it:

```bash
scripts/aha.sh get epics/DEVP-E-8 -q 'fields=reference_num,name,workflow_status,assigned_to_user'
scripts/aha.sh get features/DEVP-123 -q 'fields=reference_num,name,workflow_status,release,assigned_to_user'
scripts/aha.sh get ideas/DEVP-I-42 -q 'fields=reference_num,name,workflow_status,endorsements_count,description'
```

URL-to-type mapping: `/epics/` -> `epics`, `/features/` -> `features`,
`/ideas/` -> `ideas`, `/requirements/` -> `requirements`.

## Search ideas in a product

```bash
# Free-text search (spaces are fine; the script encodes them)
scripts/aha.sh get products/DEVP/ideas -q 'q=rate limiting' \
  -q 'fields=reference_num,name,endorsements_count,workflow_status' -q per_page=50

# Ideas created/updated since a date
scripts/aha.sh get products/DEVP/ideas -q 'created_since=2026-01-01' \
  -q 'fields=reference_num,name,created_at' --paginate
```

Read page 1 first. Only add `--paginate` when the user wants the full set --
idea portals can run to dozens of pages.

## Check if an idea already exists before logging a new one

Before creating a duplicate, search:

```bash
scripts/aha.sh get products/DEVP/ideas -q 'q=<the customer ask in 2-3 keywords>' \
  -q 'fields=reference_num,name,endorsements_count' -q per_page=25
```

If a strong match exists, prefer adding a proxy vote (below) over creating a new
idea -- consolidating endorsements is what gets things prioritized.

## List a customer's ideas and assess status (pull-and-assess)

A customer is an Aha *idea organization*; the ideas they care about are the ones
they've endorsed (proxy votes). `scripts/customer-ideas.sh` does the whole flow
in one command -- resolve the org(s), pull every endorsed idea's ref + name +
vote weight in a single paginated pass per org (`fields=idea,weight`, no per-idea
call to list them), then fetch only `workflow_status` for the unique ideas *in
parallel*, and print an open-vs-closed table.

```bash
scripts/customer-ideas.sh "HealthEquity"          # full assessed table
scripts/customer-ideas.sh "HealthEquity" --open   # only still-open ideas
scripts/customer-ideas.sh "HealthEquity" --json   # assessed array, pipe to jq
scripts/customer-ideas.sh --org ACCOUNT-O-32404   # pin to one org, skip search
```

Why it's fast: the endorsements endpoint embeds the idea (`fields=idea,weight`)
so listing a customer's ideas is 1-2 calls, not N. The embedded idea is a *short*
form (`id, name, reference_num` only) -- `workflow_status` is **not** included
and Aha has no deep field selection here, so status is the one unavoidable
per-idea fetch; the script parallelises it (`CUSTOMER_IDEAS_PARALLEL`, default 6,
under Aha's 20 req/s). A spaced name retries without spaces ("Health Equity" ->
"HealthEquity"). Idea status is always fetched live -- it's the volatile field
you're assessing, so it is never cached.

To do it by hand (e.g. a one-off variant): search `idea_organizations -q 'q=NAME'`
for the id, then `idea_organizations/{id}/endorsements --paginate -q
'fields=idea,weight'`, then GET each `ideas/{ref}` for `workflow_status`.

## Log a proxy vote (endorsement) on a customer's behalf

This is the most common write. The endpoint is `ideas/{ref}/endorsements` (NOT
`ideas/{ref}/votes`), the body is keyed on `idea_endorsement`, and the dollar
field is `value` (NOT `vote_weight`). Verified live on konghq.aha.io 2026-06-15.

Confirm the idea reference, the customer org, the submitting Kong user's email,
and the value with the user, then:

```bash
scripts/aha.sh post ideas/DEVP-I-42/endorsements -d '{
  "idea_endorsement": {
    "email": "you@konghq.com",
    "idea_organization_id": 7210570342900669490,
    "value": 25000,
    "link": "https://...",
    "description": "<p>Account: Acme. Why this matters to this account ...</p>"
  }
}'
```

- `idea_organization_id` is the numeric org id; it ties the endorsement to the
  customer account. Resolve it from `idea_organizations`, and when a parent brand
  has many near-identical orgs, disambiguate by the Salesforce account Id in the
  org's `integration_fields` (`name=="Id"`, `service_name=="salesforce"`), not by
  name. Known alias: a bare "Sony" means **Sony Interactive Entertainment LLC**
  (Salesforce Id `0011K000029btLYQAY`, Aha org id `7210570342900669490`), not the
  dozens of other Sony orgs; the `skill-cache aha customers` entry resolves it.
- `email` sets the vote's owner -- the "Created by" shown in the Aha Votes panel
  -- and is **create-only**. A proxy vote is logged BY a Kong employee ON BEHALF
  OF the account, so this is the **submitting Kong user's own email** (e.g.
  `you@konghq.com`), NEVER the customer's. Putting a customer address here makes
  the vote read as if the customer cast it themselves, which is wrong. The
  customer is identified by `idea_organization_id` and named in the `description`
  body, not by `email`. (If you don't know the Kong user's address, ask; do not
  fall back to the customer contact.)
- `value` is the dollar value. OMIT it entirely when the ask is post-deal or not
  tied to an opportunity; do not send `0`.
- `description` accepts HTML. The form also carries optional custom fields
  (`reason`, `blocks_customer`, `when_does_the_customer_need_it_by`, `stage`,
  `probability`, `close_date`) set via a `custom_fields` object keyed by field
  key. They are optional; only set what you have a clear signal for.

Caveat: many Aha tokens are reviewer-role and can POST an endorsement but get
`403` on PUT/DELETE, and `email`/custom fields are create-time. So get the org,
email (the Kong submitter, see above), value, and any custom fields right on the
first POST; there is no clean API undo. A wrong owner cannot be fixed via the API
with a reviewer token: the only remedy is the user deleting the bad vote in the
Aha UI and re-creating it, which double-counts the account until they do. Getting
the owner right on the first POST avoids that cleanup entirely.

After it lands, read the idea back to confirm the endorsement count moved:

```bash
scripts/aha.sh get ideas/DEVP-I-42 -q 'fields=reference_num,endorsements_count'
```

For the full "file an FR document + per-customer proxy votes" workflow, use the
`log-aha` skill, which wraps these calls (idea create, org resolution, markdown
to HTML, the endorsement body shape, and the optional custom fields).

## Create an idea

Confirm title, description, and target portal/product with the user first:

```bash
scripts/aha.sh post products/DEVP/ideas -d @idea.json
```

Where `idea.json` is:

```json
{
  "idea": {
    "name": "Short, specific title",
    "description": "<p>The customer problem and desired outcome.</p>",
    "skip_portal": true
  }
}
```

- `skip_portal: true` keeps it internal (no customer-portal submission).
- To attribute it to a portal user, use `submitted_idea_portal_id` instead.
- `description` accepts HTML.

Prefer `@file` for bodies with prose -- it avoids shell-quoting pain.

## Walk an epic's features / a release's contents

```bash
# Features under a product, filtered to an epic UNVERIFIED param name --
# confirm by inspecting one feature's `epic` field first
scripts/aha.sh get products/DEVP/features --paginate \
  -q 'fields=reference_num,name,epic,workflow_status'

# A release and its features
scripts/aha.sh get releases/DEVP-1.0 -q 'fields=reference_num,name,release_date'
```

## Add a comment to a record

```bash
scripts/aha.sh post features/DEVP-123/comments \
  -d '{"comment":{"body":"<p>Note from CSM: customer X is blocked on this.</p>"}}'
```

## Pull everything (full dump) for offline analysis

```bash
scripts/aha.sh get products/DEVP/ideas --paginate --per-page 200 \
  -q 'fields=reference_num,name,endorsements_count,workflow_status,created_at' \
  > /tmp/devp-ideas.json
```

`--paginate` already sleeps between pages; for very large products this still
takes a minute and counts against the 300 req/min budget -- run it once and
work from the file.

## Handoff to feature-request and log-aha

Three skills, three jobs:

- `feature-request` authors the artifacts: the customer-independent FR document
  and one per-customer proxy-vote write-up.
- `log-aha` files those artifacts into Aha: it creates the idea and attaches one
  endorsement per customer, wrapping the calls in this reference.
- This `aha` skill is the read/lookup layer and the raw API wrapper. Use it to
  *look up* or *search* existing ideas (to avoid duplicates) before a filing, and
  for any one-off read or write that the other two do not cover.

So: don't author or format FR write-ups here (that's feature-request), and for
the full file-an-FR flow prefer `log-aha` over hand-running the recipes above.
