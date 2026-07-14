---
name: upsight-import
description: Bulk-import customer meeting transcripts into the upsight app via the `upsight summarize` CLI, and reconcile disk transcripts against the upsight database to find what's missing or duplicated. Use when the user wants to import meetings into upsight, "catch up upsight", process the last N days/weeks of meeting notes, check which meetings are already in upsight, or find/clean duplicate meeting summaries. Triggers on "import meetings into upsight", "what meetings are missing from upsight", "bulk summarize", "upsight is behind", or after downloading a batch of meeting transcripts.
allowed-tools: ["Bash", "Read", "Grep", "Glob"]
---

## Purpose

Get customer meeting transcripts from disk into the upsight app, without creating
duplicates and without missing anything. Two jobs:

1. **Audit** — reconcile transcript files on disk against the meetings already in
   the upsight database, for a given time window.
2. **Import** — run `upsight summarize` on each missing transcript so its summary
   lands in the app.

Account names and the customer list are never hardcoded here. All database reads
(accounts, existing meetings, duplicate/health checks) go through the
**`upsight-db`** skill; this skill owns the disk side (transcripts) and the
import write (`upsight summarize`). The disk holds the transcripts, the database
holds the accounts.

## Key facts (verified 2026-07-13 — re-verify if the CLI version changed)

- **The CLI always uses `~/.local/share/upsight/upsight.db`.** It IGNORES
  `[database].path` in `~/.config/upsight/config.toml`. So does the Electron app.
  Do not waste time "fixing" the config DB path — it has no effect on the CLI.
- **Meeting notes live at** `<notes-root>/<Account>/**/<YYYY-MM-DD>/*.txt`, where
  `<notes-root>` defaults to `~/insync/kong/My-drive/Customer`. Each held meeting
  is a `.txt` transcript inside a date-named folder.
- **`upsight summarize` infers details from the folder path:**
  | Field | Source |
  |-------|--------|
  | `meeting_date` | the current folder name when it is `YYYY-MM-DD` (else today) |
  | `meeting_name` | the **parent** folder name (the dir above the date folder) |
  | transcript | the single `*.txt` in the folder (or `--transcript <file>`) |
  | account | `--account "<name>"` (NOT inferred reliably — always pass it) |
  Override any inferred field with `--date` / `--meeting-name`.
- **Dedup key:** `meeting_summaries` has a UNIQUE index on
  `(account_id, meeting_name_norm, meeting_date)` where
  `meeting_name_norm = lower(trim(replace(meeting_name,'-',' ')))`. Two meetings
  with differently-worded names on the same day are NOT deduped — they become two
  rows. Reconcile by `(account, date)` first, then eyeball names.
- Each `summarize` invokes the AI (`claude`) to generate the summary — budget
  ~60–120s per meeting. An interrupted run leaves a row stuck
  `status='processing'`; delete it before retrying that meeting.

## Resolving a disk folder to an upsight account

Never write the customer list into this skill. Resolve it live through the
`upsight-db` skill:

1. Get the accounts (these are the only accounts that can receive imports) via
   the `upsight-db` skill — `scripts/list-accounts.sh`, or
   `list-accounts.sh --like "<fragment>"` to filter.
2. Derive a candidate name from the disk path, usually the top-level folder under
   `<notes-root>`. For an organisation with several sub-entities, the
   distinguishing sub-folder is the better candidate.
3. Match the candidate against the accounts (`list-accounts.sh --like`):
   - **Unique hit:** use that account's exact `account_name` for `--account`.
   - **No hit:** the account probably doesn't exist in upsight. It cannot be
     imported; flag it to the user and skip (offer to create the account in the
     app first if they want it).
   - **Ambiguous, or one folder covers multiple entities:** read the transcript
     and sub-folder to decide, and if still unclear, show the user the account
     list and ask which one.
4. Some folders map to an account whose name shares no substring with the folder,
   so the filter returns nothing. Don't guess an id; present the account list and
   let the user pick.

## Workflow

1. **Pick the window.** Default: last 2 weeks. Convert to an absolute
   `--since YYYY-MM-DD`.
2. **Scan disk** for candidate transcripts:
   ```
   scripts/scan-transcripts.sh --since 2026-06-29
   ```
   Emits one line per transcript: `date | folder | meeting-name | path`.
3. **List what's already in upsight** for the same window, via the `upsight-db`
   skill:
   ```
   scripts/list-meetings.sh --since 2026-06-29
   ```
4. **Reconcile.** For each disk transcript, resolve its folder to an account (see
   above) and check whether a DB row exists for that `(account, date)`. What's on
   disk but not in the DB is the import list. Watch for same-meeting-different-name
   and duplicate date folders (identical `.txt` in two folders → import once).
   Confirm the import list with the user.
5. **Close the upsight app before bulk-importing.** It holds `upsight.db` open;
   the app won't show new rows until restarted, and this dir is Syncthing-synced
   so concurrent writers risk conflicts. Snapshot first:
   `cp ~/.local/share/upsight/upsight.db ~/.local/share/upsight/backups/upsight-pre-import-$(date +%Y%m%d-%H%M%S).db`
6. **Import** each missing meeting. Let the folder supply date + name; pass the
   account explicitly:
   ```
   cd "<.../Account/.../Meeting Name/YYYY-MM-DD>"
   upsight summarize . --account "<resolved account>"
   ```
   Or be fully explicit (recommended for scripted batches, avoids surprises):
   ```
   upsight summarize . --account "<acct>" --date YYYY-MM-DD --meeting-name "<title>"
   ```
   Batches of AI calls exceed a single 2-minute shell timeout — run the loop as a
   background job, not one blocking call.
7. **Verify** via the `upsight-db` skill — no `status<>'completed'` rows, no
   logical duplicates, integrity ok:
   ```
   scripts/verify-db.sh
   ```
8. **Tell the user to restart the app** to see the imported meetings.

## Finding & fixing duplicates

Use the `upsight-db` skill's `verify-db.sh` (it reports logical duplicates:
same account + date + normalized name). Those shouldn't exist. The same meeting
under two different names is a soft duplicate: keep the row with the richer
`full_summary`/`slack_summary` and delete the other by `id`. Always snapshot the
DB before any `DELETE`/`UPDATE` (see the `upsight-db` skill's safety notes).

## Safety

- Read-only reconciliation is free; the destructive parts are `summarize` (writes
  a row + calls AI) and any manual `DELETE`/`UPDATE`. Snapshot before writes.
- Never run a probe/import against a copied "scratch" DB expecting the CLI to
  honor it — the CLI ignores the config path and writes to the real
  `upsight.db`. Test only with throwaway `--account`/dates you will delete, or
  accept it hits prod.
- If the user wants an account that doesn't exist in upsight, stop and flag it —
  don't guess an account_id.
