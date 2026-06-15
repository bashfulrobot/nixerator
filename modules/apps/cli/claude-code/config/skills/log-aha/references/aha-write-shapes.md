# Aha write shapes and gotchas (verified)

The exact request bodies for the two writes this skill makes, plus the failure
modes that cost real time to rediscover. Verified against konghq.aha.io and the
Aha API docs on 2026-06-15.

## Create an idea

```
POST /api/v1/products/{PREFIX}/ideas
{
  "idea": {
    "name": "Short capability-named title",
    "description": "<p>HTML ...</p>",
    "skip_portal": true
  }
}
```

- `description` accepts HTML. `build-idea-json.sh` produces this from the FR
  markdown via pandoc.
- `skip_portal: true` creates the idea internally (no customer-portal
  submission). Use this when Kong logs the idea on the customer's behalf and
  attaches a proxy vote. The FR body is written customer-independent for PM
  triage, not for the portal.
- A fresh idea lands in workflow_status "Needs review".

## Add a proxy vote (endorsement)

```
POST /api/v1/ideas/{REF}/endorsements
{
  "idea_endorsement": {
    "email": "contact@customer.com",
    "idea_organization_id": 7210570342900669490,
    "value": 25000,
    "link": "https://...",
    "description": "<p>Why this matters to this account ...</p>"
  }
}
```

- Endpoint is `/endorsements`, NOT `/votes`. The earlier skill notes that said
  `ideas/{ref}/votes` with `vote_weight` were wrong for this purpose.
- The dollar field is `value`, not `vote_weight`. OMIT it entirely when the ask
  is post-deal or not tied to an opportunity. Do not send `0`.
- `idea_organization_id` is the numeric org id (19 digits at Kong). jq 1.7+
  preserves the literal, so it round-trips without precision loss.
- `email` is create-only.

## Reviewer-role tokens cannot fix mistakes

Observed on konghq.aha.io: the `AHA_API_TOKEN` in this environment is a
**reviewer** role. It can POST ideas and endorsements but gets `403 "Access
denied. Your role is 'reviewer'."` on DELETE and PUT of an endorsement. Aha also
treats endorsement `email` as create-only.

Consequence: there is no clean API undo. Get the org, email, and value right on
the first POST. Confirm all three with the user before calling
`add-proxy-vote.sh`. A wrong endorsement has to be removed in the Aha UI or with
a contributor/owner-role token.

## Proxy-vote custom fields (all OPTIONAL)

The proxy-vote form carries custom fields beyond the native ones. They are
**optional**: fill one only when the proxy-vote doc gives a clear signal, and
leave the rest blank. Never block a filing on them, and never invent a value to
fill a box.

They are also effectively **create-time** for a reviewer-role token (no edit
after the fact), so set them on the POST via `idea_endorsement.custom_fields`
(an object keyed by the field key). `add-proxy-vote.sh` does this with `--cf`,
`--cf-file`, and `--cf-num`.

| Label | key | Type | How to fill |
|-------|-----|------|-------------|
| Reason? | `reason` | note (HTML) | Why the idea should be prioritized. Often "See description." plus the one-line account driver. |
| Blocks customer? | `blocks_customer` | dropdown | Exactly one of the two option strings below. |
| When does the customer need it by? | `when_does_the_customer_need_it_by` | date | `YYYY-MM-DD`. Omit when there is no date (not a blocker / post-cutover). |
| Stage | `stage` | dropdown | Salesforce opportunity stage. Leave unset (form default "None") when the ask is post-deal / not tied to an opportunity. |
| Probability | `probability` | number | Opportunity probability. Usually unset for post-deal asks. Use `--cf-num`. |
| Close date | `close_date` | date | Opportunity close date. Usually unset for post-deal asks. |

`blocks_customer` allowed values (verified from the form; must match exactly):
- `Yes, this will block the customer eventually.`
- `No, this is just an idea.`

`stage` allowed values (Salesforce opportunity stages; verified from the form):
`0. Disco Scheduled (SQL)`, `0. Pending Renewal`, `1. Disco Completed (SQL)`,
`1. Disco Scheduled`, `2. Engage (SAL)`, `2. Engage (SQL)`, `3. Qualify (SAL)`,
`3. Qualify (SQL)`, `4. Evaluate`, `5. Go/No-Go`, `6. Validate`, `7. Negotiate`,
`8. Close Deal`, `Active Demo Instance`, `Closed Demo Instance`, `Closed Lost`,
`Closed Merged`, `Closed Won`, `Close Won`, `Disqualified`, `In Review`. Default
is None (unset).

The API does not expose these allowed lists, so they are recorded here from the
Aha UI. The `stage` and `blocks_customer` options can change; if a write 422s on
one, re-read the dropdown in the proxy-vote form.

## Org disambiguation by Salesforce id

A parent brand has many near-identical idea_organizations (the Kong account had
six "Sony Interactive ..." orgs). Names are not a safe selector. The Salesforce
account Id is. It lives in the org's `integration_fields` where `name=="Id"` and
`service_name=="salesforce"`. `resolve-org.sh` extracts it; pass the SFDC id
from the proxy-vote doc (or from the sfdc/Salesforce account) to pin the match.

## Known Kong product prefixes

Resolve a product area to its idea-portal reference prefix. Verified:

| Product area (FR "Product area") | Prefix | Aha workspace |
|----------------------------------|--------|---------------|
| Kong Operator / Kubernetes       | `KUB`  | Kubernetes    |

Others (Gateway, Konnect, Mesh, Insomnia, AI Gateway, Dev Portal) exist but are
not yet verified here. Resolve an unknown one with
`aha.sh get products -q 'fields=name,reference_prefix' --paginate`, confirm with
the user, and add it to this table (and the skill-cache) once confirmed.
