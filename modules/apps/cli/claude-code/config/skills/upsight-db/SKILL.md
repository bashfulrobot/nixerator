---
name: upsight-db
description: Query the local upsight app's SQLite database directly for accounts, meetings, agendas, cases, tasks, and other CRM data. Use whenever you need to READ upsight data — list accounts, look up an account id by name, list/verify meeting summaries, check for duplicate meetings, or answer "what's in upsight for X". Other upsight skills (e.g. upsight-import) call this skill for their database reads. Triggers on "query upsight", "upsight database", "upsight sqlite", "what accounts are in upsight", "account id for", "meetings in upsight", "check the upsight db".
allowed-tools: ["Bash", "Read"]
---

## Purpose

A single, reusable place that knows how to read the upsight application's SQLite
database. Reads only. Anything that writes (importing a meeting summary, editing a
row) is out of scope for this skill — but the safety rules here apply to those
writers too.

## The database

- **Path (fixed):** `~/.local/share/upsight/upsight.db`.
- **The CLI and the Electron app always use this file.** They IGNORE
  `[database].path` in `~/.config/upsight/config.toml`. Do not trust that config
  line and do not point queries at `upsight-dev.db` or any copy — those are stale
  and not what the app reads. (Verified 2026-07-13.)
- The app holds the DB open while running; concurrent reads are fine. This dir is
  Syncthing-synced, so avoid writing while the app is open.
- Schema and the table map: see `references/schema.md`.

## Common reads

Run these with `sqlite3`. Use `-header -column` for human output, `-json` or
`-csv` when another tool will parse it.

**List accounts / resolve a name to an id:**
```
scripts/list-accounts.sh                      # id + name, all accounts
sqlite3 ~/.local/share/upsight/upsight.db \
  "SELECT id, account_name FROM accounts WHERE account_name LIKE '%acme%';"
```

**Meetings in a date window:**
```
scripts/list-meetings.sh --since 2026-06-29
```

**Duplicate / integrity check:**
```
scripts/verify-db.sh
```

**Ad-hoc:** query any table from `references/schema.md`, e.g. open cases,
upcoming renewals, tasks for an account. Join to `accounts` on `account_id` to
get names.

## Resolving an account by name

Account names in the DB rarely match a folder or a casual name exactly (legal
suffixes, sub-entities, abbreviations). Resolve, don't assume:

1. Substring search: `... WHERE account_name LIKE '%<fragment>%'`.
2. One row → use its `id` / exact `account_name`.
3. Zero rows → the account isn't in upsight. Say so; don't invent an id.
4. Multiple rows (common for parent/child orgs) → show them and let the caller
   or user choose.

## Safety

- Default to read-only. `SELECT`/`PRAGMA` only.
- If a caller needs a write, that's the caller's job — but first snapshot:
  `cp ~/.local/share/upsight/upsight.db ~/.local/share/upsight/backups/upsight-$(date +%Y%m%d-%H%M%S).db`
  and prefer doing it while the app is closed.
- Never surface secret-like fields (tokens, URLs with embedded credentials) into
  chat. Account CRM fields (health, ARR, renewal dates) are business-sensitive —
  share them with the user, but don't paste them anywhere external.
