---
name: sfdc
description: >-
  Expert Salesforce CLI (sf) skill for querying and (carefully) updating data
  in Salesforce orgs. Use ONLY when the user explicitly asks about Salesforce,
  SFDC, SOQL, running sf CLI commands, or invokes /sfdc. Trigger phrases
  include "query Salesforce", "run a SOQL query", "pull data from SFDC",
  "describe this SObject", "update this Account/Contact/Opportunity in
  Salesforce", "export Cases to CSV". Do NOT trigger on tangential Salesforce
  mentions (e.g., someone mentioning a Salesforce URL in passing) or on
  operations that another skill owns -- the log-support-ticket skill owns
  Case creation; delegate there. Covers SOQL patterns, sobject describes,
  bulk exports, and destructive operations behind a strict confirmation
  playbook. Defaults to read-only; any write requires explicit per-run
  confirmation.
---

# Salesforce CLI (sfdc)

Work with Salesforce via the `sf` CLI. Default posture is read-only. Any
command that mutates data requires the writes playbook -- no shortcuts.

## Why this skill exists

Salesforce is a production system of record. Most of what you'll be asked to
do is pull data: counts, lists, exports, reports. Occasionally you'll be
asked to change something. The cost of a wrong UPDATE or DELETE is high:
corrupted records, broken reports, triggered workflows that cascade across
the org, and real customer impact if it hits Cases or Accounts.

The guiding principle: **read freely, write rarely, and only with the user
watching every step**.

## Context folder and memory

This skill keeps persistent, project-style memory in a dedicated folder.
Defaults to `~/sfdc/`; override with `$SFDC_CONTEXT_DIR` if needed. The
folder holds:

- `.graymatter/` -- the GrayMatter memory database (agent ID: `sfdc`)
- `.mcp.json` -- wires `graymatter` as an MCP server if the user `cd`s into
  the folder for a session
- `CLAUDE.md` -- directs any Claude session started in that folder to use
  the graymatter MCP for memory

This skill itself doesn't require the MCP to be active in the current
session. It uses the `graymatter` CLI with `--dir` so it works from any
working directory.

### Step 0: Bootstrap (run once on first use)

At the start of every SFDC task, check the context folder exists:

```bash
test -f "${SFDC_CONTEXT_DIR:-$HOME/sfdc}/.graymatter/gray.db" \
  || bash "$(dirname "$0")/scripts/bootstrap-context.sh"
```

Or, more simply, run the bootstrap script -- it's idempotent:
```bash
bash scripts/bootstrap-context.sh
```

### Recall before acting

For any non-trivial SObject, query, or named record, check memory first:

```bash
graymatter recall sfdc "<natural-language query>" \
  --dir "${SFDC_CONTEXT_DIR:-$HOME/sfdc}/.graymatter"
```

Examples of what's worth recalling: field names on custom objects, working
SOQL patterns, account/opportunity IDs the user has named, gotchas hit
previously.

### Store what's reusable

After a task, if you learned something that would save time next session,
store it:

```bash
graymatter remember sfdc "<concise fact>" \
  --dir "${SFDC_CONTEXT_DIR:-$HOME/sfdc}/.graymatter"
```

Reusable: field API names on custom objects, SOQL patterns, record IDs the
user referenced by name ("our Acme account"), org-specific gotchas
(required fields, validation rules, read-only formula fields, triggers that
fire on write).

Not reusable: the output of one-off queries, transient task state, details
the user can rediscover trivially.

## Workflow

### Step 1: Classify the request

Before running anything, decide:

- **Read** -- `sf data query`, `sf data export`, `sf sobject describe`,
  `sf data get record`. Safe. Proceed normally.
- **Write** -- `sf data create/update/delete/upsert` (singular or bulk),
  `sf data import`. Stop and follow `references/writes-playbook.md`.
- **Case creation specifically** -- delegate to the `log-support-ticket`
  skill. Do not reimplement.

### Step 2: Confirm the target org

There's no undo for "oops, I ran that against production". Always verify:

```bash
sf org display --json | jq -r '.result | "Alias: \(.alias // "none")\nUser:  \(.username)\nOrg:   \(.instanceUrl)"'
```

If the user hasn't specified an org and the default isn't obviously the
right one, ask. For writes, ALWAYS echo the target org in the plan you show
the user.

### Step 3 (reads): Discover, then query

If the SObject or fields aren't already known to you or in memory:

```bash
bash scripts/sfdc-describe.sh <SObjectName> --fields-only
```

This prints a compact table: field API name, label, type, updateable. For
the full describe JSON, omit `--fields-only`.

Then run the query. See `references/soql-cheatsheet.md` for SOQL syntax,
date literals, and common gotchas. See `references/common-commands.md` for
the full `sf` command reference.

```bash
# Default: human-readable table
bash scripts/sfdc-query.sh "SELECT Id, Name FROM Account LIMIT 5"

# JSON (programmatic use, piping into jq)
bash scripts/sfdc-query.sh --json "SELECT Id, Name FROM Account LIMIT 5"

# CSV (reports, spreadsheet handoff)
bash scripts/sfdc-query.sh --csv "SELECT Id, Name FROM Account LIMIT 5"
```

For result sets >2000 rows, use bulk mode (the query script handles this
automatically with `--bulk`):
```bash
bash scripts/sfdc-query.sh --bulk --csv "SELECT ... FROM Opportunity"
```

### Step 4 (writes): Follow the playbook

Read `references/writes-playbook.md` before every write. The playbook
enforces: classify -> describe -> find (SELECT) -> count -> plan -> explicit
user confirmation -> canary (for bulk) -> execute -> verify -> store lesson.

Do not skip steps even for "obviously safe" changes. The discipline is the
whole point.

### Step 5: Store any lesson

After the task, if something you learned will save time next time, save it
to graymatter (see "Store what's reusable" above).

## Output format defaults

- **Human-readable table** -- default for interactive use
- **JSON** -- when the user asks for it, or when you're piping into `jq`,
  another script, or building a programmatic pipeline
- **CSV** -- when the user asks for a report, spreadsheet handoff, or
  anything they'll open in Excel/Numbers

If the user requests a recurring report, consider writing a small shell
script they can run on demand. Put it wherever they direct (often in their
project folder), and have it source the context folder so graymatter memory
is available if needed.

## What NOT to do

- Do not run a write command without the playbook, even if the user seems
  to be in a hurry. A delayed yes is cheaper than a wrong write.
- Do not store raw query results in graymatter. Store the *pattern* that
  produced them, not the data.
- Do not invent field API names. Describe the object. Custom fields almost
  always end in `__c`; some standard fields have non-obvious names (e.g.,
  `AccountId` on Contact, `IsClosed` on Opportunity).
- Do not `SELECT *` -- SOQL doesn't support it. Always list fields
  explicitly, or describe first.
- Do not trigger on passing mentions of Salesforce. If the user says "yeah
  we use Salesforce" while discussing something else, stay silent.
- Do not duplicate the `log-support-ticket` skill. If the user wants to
  create a Support Case, direct them there.

## Files in this skill

### references/

- `soql-cheatsheet.md` -- SOQL syntax, date literals, operators, aggregate
  functions, relationship queries, LIMIT/OFFSET, common gotchas
- `common-commands.md` -- `sf data`, `sf sobject`, `sf org` command
  reference with flags, examples, and JSON output parsing tips
- `writes-playbook.md` -- the destructive-operation workflow. Read it
  before any write. Every time.

### scripts/

- `bootstrap-context.sh` -- idempotent init of the context folder
- `sfdc-query.sh` -- SOQL runner with human/json/csv/bulk modes
- `sfdc-describe.sh` -- SObject describe with compact `--fields-only` mode
- `sfdc-count.sh` -- COUNT() sanity check, used by the writes playbook
