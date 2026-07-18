# Source-resolution map (per-customer, cached)

For a given customer the same identifiers recur across every task on the
account: the internal Slack channel, the local notes dir, the Jira prefixes
seen, the key contacts, the cadence meetings. Resolve each **once** and cache
it, so the fifth `Kong-lululemon` task in a batch doesn't re-derive what the
first one already found.

Uses the **`skill-cache`** warm-cache CLI (internal, on PATH). Full convention:
`.claude/docs/skill-cache.md`.

## What to cache — and what never to

Cache only **stable name→identifier mappings**. These change rarely and are safe
to reuse across a run:

| Table | Key | Value (identity — no `--ttl`) |
|---|---|---|
| `customers` | customer / project name | `{ "slack_channel": "#internal-lululemon", "notes_dir": "~/insync/kong/My-drive/Customer/Lululemon/", "jira_prefixes": ["LULU","DEVP"], "sfdc_account": "001..." }` |
| `contacts` | customer name | `{ "customer_side": [...], "kong_side": [...] }` (names/handles, **not** secrets) |
| `routing` | person's name | `{ "medium": "slack-dm\|slack\|teams\|email", "id": "<channel or DM id>", "note": "prefers DM" }` |

**Routing** answers "how do I reach this person", not just "who are they" — the
`teams` vs `send` verb choice and the channel id both come from here, so a nudge
doesn't re-resolve them every run. It's a stable name→identifier mapping like the
others, so it obeys the same rule below: no live state, no message contents.

- **Teams is a first-class `medium`, not an afterthought.** The work-log sweep
  found Teams is the 2nd most common channel (some accounts, e.g. a PS contact,
  live in Teams, not Slack). The `routing.medium` field above already carries
  `teams` — populate it so a nudge routes to the `teams` verb (clipboard
  hand-send) instead of defaulting to Slack. No new field needed; `medium` is it.

Slow metadata (CSM owner, segment) may use `--ttl 30d`. **Never cache live
state** — never `put` a task's contents, due date, status, `days_silent`, ticket
state, or thread recency. Those are read live on every assessment, always.

## Resolve-then-cache pattern

```bash
# Slack channel for a customer
if hit=$(skill-cache get todoist-triage customers "lululemon" 2>/dev/null); then
  channel=$(printf '%s' "$hit" | jq -r '.slack_channel // empty')
fi
if [ -z "${channel:-}" ]; then
  # resolve once via the Slack MCP (slack_search_channels for #internal-lululemon),
  # then persist the whole customer record:
  skill-cache put todoist-triage customers "lululemon" \
    '{"slack_channel":"#internal-lululemon","notes_dir":"~/insync/kong/My-drive/Customer/Lululemon/","jira_prefixes":["LULU"]}' \
    --alias "kong-lululemon"
fi
```

- Register the Todoist project name as an `--alias` (e.g. `kong-lululemon`) so
  either form hits.
- On a hit, use the cached identifiers directly — no lookup.
- If Dustin says a mapping is wrong (channel moved, customer renamed),
  `skill-cache forget todoist-triage customers "<name>"` and re-resolve.

## Todoist id cache

The `todoist-cli` skill already owns a `todoist` cache table for project /
label / section ids. Reuse it via the `td` skill's convention rather than
duplicating those ids here — this skill's `customers`/`contacts` tables are for
the *cross-source* identifiers `td` doesn't know about.
