---
name: log-aha
description: >-
  File a feature-request into Aha! as a product idea plus one proxy-vote
  endorsement per customer, via the Aha REST API. Use when the user has
  feature-request output (an FR markdown file and one or more proxy-vote files)
  and wants it filed in Aha, or says "log this to Aha", "file the FR in Aha",
  "create the Aha idea", "push the feature request to Aha", "add the proxy
  vote", "log the FR", or "/log-aha". This is the filing half of the workflow
  whose authoring half is the feature-request skill: feature-request writes the
  artifacts, log-aha files them. Trigger eagerly right after a /feature-request
  run when the user wants it submitted. Do NOT use this for general Aha lookups,
  status checks, or searches (reference numbers like KUB-129, "what's the status
  of", "search Aha for ...") -- that is the `aha` skill. And do NOT author or
  redact the FR here; that belongs to feature-request.
---

# Log to Aha

File a feature-request as an Aha idea and attach one proxy-vote endorsement per
source customer. Scripts in `scripts/` handle the Aha API deterministically
(auth, body shapes, big-integer org ids, pandoc markdown-to-HTML). Your job is
to orchestrate: locate the artifacts, resolve the product and customer
identifiers, confirm the few judgment calls, and run the writes in order.

This skill consumes what the `feature-request` skill produces and keeps the same
split: the customer-independent FR becomes the idea body (no customer names,
ARR, quotes, or dates), and each per-customer proxy-vote doc becomes an
endorsement carrying that account's context. Authoring and redaction already
happened upstream; do not redo them here, but do run the quick safety scan in
Step 1 so a leak never reaches the idea body.

## Prerequisites

- `AHA_API_TOKEN` in the environment (an Aha API key). Never echo it.
- `curl`, `jq` (1.7+ for big-int org ids), and `pandoc` on PATH.
- Default account is `konghq.aha.io`; override with `AHA_SUBDOMAIN`.

Read `references/aha-write-shapes.md` before the first write of a session. It
holds the verified request bodies, the reviewer-role limitation (no API undo),
and the product-prefix table.

## Scripts

All scripts are in `scripts/` relative to this file. Run them with `bash`. Each
prints JSON to stdout and errors to stderr.

| Script | Purpose | Args |
|--------|---------|------|
| `aha.sh` | Thin Aha REST wrapper (auth, query encoding, `--paginate`) | `<method> <path> [-q k=v] [-d json|@file]` |
| `resolve-org.sh` | Customer name -> idea_organization candidate(s), disambiguated by Salesforce id | `"<name>" [sfdc_id]` |
| `build-idea-json.sh` | FR markdown -> idea JSON body (H1 = name, rest = HTML description) | `<fr.md> [--portal]` |
| `add-proxy-vote.sh` | Create an endorsement with the correct body shape + optional custom fields | `<idea_ref> <org_id> <email> [--value N] [--link URL] [--desc HTML|--desc-file F] [--cf key=val] [--cf-file key=path] [--cf-num key=N]` |

## Workflow

Follow in order. Use `AskUserQuestion` for the selections noted. Treat every
POST as a write that needs an explicit yes for that call (see Constraints).

### Step 0: Locate the artifacts

The input is feature-request output, usually in `$PWD/feature-requests/`:
- exactly one FR file: `*-fr.md`
- one or more proxy-vote files: `*-proxy-vote.md`

If the user named files or a directory, use those. Otherwise glob
`feature-requests/`. Parse:
- FR: the H1 (idea name) and the header block (Product area, Category, Priority,
  Proxy-vote count).
- Each proxy-vote: the `Customer:` line (account name), the `Linked FR:` line
  (confirm it points at the FR file), and any `sfdc`/Salesforce id present in
  the account-context section.

If you cannot find a clean FR + proxy-vote pair, say so and stop. Do not invent
content; that is feature-request's job.

### Step 1: Pre-flight redaction safety scan

The idea body must carry no customer-identifying content. Build a token list
from every proxy-vote's customer name (and common short forms) plus any
stakeholder names you see, and grep the FR body for them. Any hit is a leak:
stop and tell the user which file and line, rather than filing a leak into a
product-wide (and potentially portal-visible) idea. This is cheap insurance, not
a re-authoring pass.

### Step 2: Resolve the product prefix

Map the FR "Product area" to an Aha idea-portal reference prefix using the table
in `references/aha-write-shapes.md` (e.g. Kong Operator / Kubernetes -> `KUB`).
If it is not in the table, resolve it:

```bash
bash scripts/aha.sh get products -q 'fields=name,reference_prefix' --paginate
```

Confirm the chosen product with the user via `AskUserQuestion` before creating
anything. If a `skill-cache` CLI is available, check it first
(`skill-cache get aha products "<area>"`) and write back confirmed mappings.

### Step 3: Check for a duplicate idea

Consolidating endorsements onto one idea is what gets things prioritized, so
look before creating:

```bash
bash scripts/aha.sh get products/<PREFIX>/ideas \
  -q 'q=<2-3 keywords from the idea name>' \
  -q 'fields=reference_num,name,endorsements_count,workflow_status' -q per_page=25
```

If a strong match exists, ask the user (`AskUserQuestion`) whether to attach the
proxy vote(s) to that existing idea instead of creating a new one. If yes, skip
Step 4 and use that reference in Step 5.

### Step 4: Create the idea

```bash
bash scripts/build-idea-json.sh <fr.md> > /tmp/aha-idea.json
jq -r '.idea.name' /tmp/aha-idea.json   # show the user the title
```

Show the title (and note `skip_portal: true`, i.e. created internally). On a
yes, create it and capture the reference:

```bash
bash scripts/aha.sh post products/<PREFIX>/ideas -d @/tmp/aha-idea.json \
  | jq '.idea | {reference_num, name, workflow_status: .workflow_status.name, url}'
```

Hold the `reference_num` (e.g. `KUB-I-92`) for Step 5.

### Step 5: Add a proxy vote per customer

For each proxy-vote file:

1. **Resolve the org.** Prefer the Salesforce id from the proxy-vote doc to pin
   the exact account; a parent brand has many near-identical orgs.
   ```bash
   bash scripts/resolve-org.sh "<customer name>" <sfdc_id>
   ```
   If you have no SFDC id, run it with the name only and present the candidates
   (name, ref, sfdc_id, endorsements_count) with `AskUserQuestion` so the user
   picks the right one. Never guess between similar orgs.

2. **Gather the two judgment inputs and confirm them** (these cannot be fixed
   after the POST -- see the reviewer-role note):
   - `email`: the contact the endorsement is attributed to. The customer's
     requesting contact is the natural default; the submitting CSM is a valid
     alternative. Ask via `AskUserQuestion` if unclear.
   - `value`: the dollar value. OMIT it when the ask is post-deal or not tied to
     an opportunity (do not pass `--value 0`). Only set a figure when there is a
     real opportunity-tied number, and never inflate a low-priority ask with the
     full account ACV.

3. **Compose a concise endorsement description** (HTML) from the proxy-vote
   doc's account context, "why this matters", and one or two key quotes. This is
   not the whole document; skip the filing-path and open-questions sections.

4. **Optionally set custom fields.** These are all optional, so fill a field
   only when the proxy-vote doc gives a clear signal, and leave the rest blank.
   Do not block the filing on them and do not invent values. The keys, types,
   and the exact dropdown option strings are in `references/aha-write-shapes.md`.
   The two that usually have a clean mapping:
   - `blocks_customer` (dropdown): `No, this is just an idea.` when the doc says
     it is not a blocker; `Yes, this will block the customer eventually.` when it
     is. If the doc is silent, leave it blank.
   - `reason` (HTML note): a one or two line "why prioritize this" drawn from the
     doc's driver. Pass long HTML with `--cf-file`.

   `when_does_the_customer_need_it_by` only when the doc names a date. Leave
   `stage`, `probability`, `close_date` unset for post-deal asks not tied to an
   opportunity. Because the token cannot edit an endorsement after creation,
   confirm any custom-field values with the user before the POST.

5. **File it** (the source link is usually the Slack thread from the proxy-vote
   doc's Source materials):
   ```bash
   bash scripts/add-proxy-vote.sh <IDEA-REF> <org_id> "<email>" \
     --link "<source url>" --desc-file /tmp/endorsement.html \
     --cf "blocks_customer=No, this is just an idea." \
     --cf-file "reason=/tmp/reason.html"
     # add --value N only if opportunity-tied; omit any --cf you have no signal for
   ```

### Step 6: Verify and report

Read the idea back and confirm the endorsement count moved:

```bash
bash scripts/aha.sh get ideas/<IDEA-REF> \
  -q 'fields=reference_num,name,workflow_status,endorsements_count,url' \
  | jq '.idea'
```

Give the user the idea URL (`https://<subdomain>.aha.io/ideas/ideas/<REF>`) and
a one-line summary: product, status, which org(s) the proxy vote(s) landed
under, and any value that was set or deliberately omitted. Clean up `/tmp`
files.

## Constraints

- **One write, one yes.** Show the exact call (method, path, body summary) and
  the target account (`konghq.aha.io`) before each POST. Approval of the idea is
  not approval of the proxy vote. Do not batch.
- **Get attribution right the first time.** The token is often reviewer-role and
  cannot edit or delete an endorsement; `email` is create-only. Confirm org,
  email, and value before `add-proxy-vote.sh`.
- **Stay in your lane.** Do not author or redact the FR (feature-request owns
  that). Do not do general Aha lookups or status reporting (the `aha` skill owns
  that). This skill only files an already-authored FR pair.
- **No customer content in the idea body.** Run Step 1 and refuse to create the
  idea while any leak remains. Proxy-vote bodies are exempt -- they are meant to
  carry customer facts.
- **Never echo `AHA_API_TOKEN`.** The scripts read it from the environment.
- **Do not auto-route elsewhere.** Filing to Aha is the whole job; do not also
  post to Slack, SFDC, or GitHub unless the user asks and invokes that skill.
