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

## Scripts

Named, deterministic helpers live in `scripts/`. Reach for one of these before
hand-writing SQL; fall back to `query.sh` only for genuinely one-off reads.

| Script | What it does |
|--------|--------------|
| `list-accounts.sh [--like FRAGMENT]` | The customer/account list (id + name). This is the canonical way to get "who are our customers" from upsight. |
| `account.sh <id\|name>` | Full record for one account. Errors on no/ambiguous match rather than guessing. |
| `list-meetings.sh [--since YYYY-MM-DD]` | Meeting summaries in a date window, with account names. |
| `verify-db.sh` | Health check: integrity, FK violations, stuck rows, logical duplicates. |
| `query.sh "<SQL>"` | Freeform READ-ONLY query. Opens the DB with `sqlite3 -readonly`, so writes fail by construction. `--format column\|json\|csv\|line\|box`; pass `-` to read SQL from stdin. |

Freeform examples:
```
scripts/query.sh "SELECT account_name, health_status, renewal_date FROM accounts WHERE renewal_risk!='Low';"
scripts/query.sh --format json "SELECT id, subject, status FROM cases WHERE status!='Closed';"
```
Join any table from `references/schema.md` to `accounts` on `account_id` to get
names.

## Growing this skill

This skill is meant to accumulate deterministic queries over time. When you find
yourself writing the same freeform `query.sh` shape more than once (open cases,
upcoming renewals, tasks for an account, consumption trends, meetings without a
Salesforce event, etc.), promote it to a named script here so the next run is a
single deterministic call instead of re-derived SQL. Keep each script:

- **Read-only** (`sqlite3 -readonly`), one clear job, `--help` from the header.
- **Parameterised** by the things that vary (account, date window, status), with
  sensible defaults.
- **Schema-checked** against the live DB before committing (schemas drift; see
  `references/schema.md` for how to re-dump).

Good candidates not yet built: open cases by account, renewals due in N days,
tasks/actions per account, account health snapshot, meetings missing a summary.
Add them as the need appears rather than all at once.

## How this skill is defined and deployed (nixerator)

A skill in nixerator is just a directory — no per-skill Nix code:

- Location: `modules/apps/cli/claude-code/config/skills/<name>/` with a
  `SKILL.md`, plus optional `scripts/` and `references/`.
- Deploy: home-manager activation (`modules/apps/cli/claude-code/cfg/activation.nix`)
  rsyncs every `config/skills/*/` into `~/.claude/skills/<name>/` on rebuild
  (`--delete` prunes removed files, `--chmod=u+w` makes them runtime-writable).
  So adding a script here and rebuilding is all it takes; there's nothing to
  register. Rebuild via the justfile (`just qr`) — and per nixerator convention,
  the user triggers rebuilds, not the agent.
- For name→id caching against slow external APIs there's the `skill-cache`
  convention (`.claude/docs/skill-cache.md`). This skill does NOT need it: the
  account list is a fast local SQLite read, not a slow remote lookup.

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
