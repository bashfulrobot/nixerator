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

This is the most common write. Confirm the idea reference, customer email, and
vote weight with the user, then:

```bash
scripts/aha.sh post ideas/DEVP-I-42/votes \
  -d '{"idea_vote":{"email":"jane@customer.com","vote_weight":10}}'
```

- `email` ties the endorsement to the customer contact.
- `vote_weight` is the strength/seat count -- get it right, it feeds
  prioritization. UNVERIFIED: confirm the exact body shape against the docs
  (https://www.aha.io/api/resources/idea_votes/create_a_proxy_vote) if the
  first call 422s; some accounts expect `link` or `name` too.

After it lands, read the idea back to confirm the endorsement count moved:

```bash
scripts/aha.sh get ideas/DEVP-I-42 -q 'fields=reference_num,endorsements_count'
```

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

## Handoff to the feature-request skill

If the user wants a written feature-request document or per-customer proxy-vote
write-ups, that's the `feature-request` skill's job. Use this skill to *look up*
or *search* existing Aha ideas to avoid duplicates, then hand the references to
feature-request for the authoring.
