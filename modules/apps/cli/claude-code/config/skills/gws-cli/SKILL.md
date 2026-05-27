---
name: gws-cli
description: Drive the `gws` (googleworkspace/cli) command-line tool to interact with any Google Workspace service from a shell. Use this skill when the user wants to send a Gmail message from the CLI, create or list calendar events, manage Google Tasks, post into a Chat space, list or move Drive files (metadata only, not edits to Docs/Sheets/Slides), run one of the bundled `+workflow` helpers (`+standup-report`, `+meeting-prep`, `+email-to-task`, `+weekly-digest`, `+file-announce`), set up gws authentication for the first time, debug a 401/403 from gws, or discover how to call a Workspace API method via `gws schema`. Trigger eagerly on phrases like "gws", "googleworkspace cli", "send a gmail from the terminal", "schedule a calendar event", "add a todoist-style task in google tasks", "post to a chat space", "list my drive files", "show today's meetings", "weekly digest", "gws auth login", "gws auth setup", "gws auth status", or "how do I call <google workspace api method>". This skill explicitly defers Google Sheets cell writes, Google Doc create/copy/replace, and Google Slides building to the `gsuite-edit` skill (same underlying `gws` tool, tighter scope for edits). For Drive *reads* of file metadata, `gws drive files list` here is fine; for reads of file *content*, prefer the Drive MCP if available.
---

# gws-cli: drive the Google Workspace CLI

`gws` (https://github.com/googleworkspace/cli) is Google's official Go CLI over every Workspace API. Single binary, one shape, native speed, no curl + ADC dance. This skill covers everything *except* the Sheets/Docs/Slides edit patterns, which live in the focused `gsuite-edit` skill.

## When to use this skill vs `gsuite-edit`

| Task | Skill |
|---|---|
| Write cells, create/copy/replace a Doc, build or fill a Slides deck | `gsuite-edit` |
| Send a Gmail, create a calendar event, add a task, post to chat, list Drive files, run `+workflow` helpers, auth setup or debug, `gws schema` lookups | this skill |

If the task crosses both (e.g. "find a template in Drive, copy it, fill it, then email the recipient"), this skill handles the Drive search and the Gmail send; `gsuite-edit` handles the copy and fill.

## One-time setup

`gws` has its own auth, separate from `gcloud` Application Default Credentials. Three steps, once per machine:

1. **Create a GCP project + OAuth client** (skip if you already have one you want to reuse):

   ```bash
   gws auth setup
   ```

   Walks through `gcloud` to create or reuse a project, enable the Workspace APIs, and emit an OAuth client. Writes `~/.config/gws/client_secret.json`.

2. **Authorize the CLI in the browser:**

   ```bash
   gws auth login
   ```

   Opens a browser, asks the user to consent to the requested scopes, stores the token in the system keyring (default) or an encrypted file fallback. Subsequent CLI calls just work; tokens refresh automatically.

3. **Confirm:**

   ```bash
   gws auth status
   ```

   Look for `"storage": "keyring"` (or `"file"`). If `"storage": "none"`, auth did not land, re-run step 2.

To rotate or revoke later: `gws auth logout` clears the local cache; re-run `login` to re-grant. To inspect the stored credential blob, `gws auth export`.

### Scope debugging

If a call returns 401 or 403 with a scope complaint, the OAuth client created by `gws auth setup` did not request the scope you need. The fix is to edit the consent screen in GCP to add the scope, then `gws auth logout && gws auth login` so the new consent screen shows up. `gws` does not maintain a per-call scope list, it relies on the consent already granted.

## Command shape

```
gws <service> <resource> [sub-resource] <method> [flags]
```

Key flags (run `gws --help` for the full list):

| Flag | Purpose |
|---|---|
| `--params '<JSON>'` | URL path + query parameters as JSON (e.g. `'{"userId":"me","maxResults":5}'`) |
| `--json '<JSON>'` or `--json @file.json` | Request body for POST / PATCH / PUT |
| `--upload <PATH>` | Local file to upload as media (multipart). Pair with `--upload-content-type`. |
| `--output <PATH>` | Output file for binary responses (downloads). |
| `--format json\|table\|yaml\|csv` | Output format. `json` is default. |
| `--page-all` | Auto-paginate, one JSON line per page (NDJSON). |
| `--page-limit <N>` | Cap pages when paginating. Default 10. |
| `--dry-run` | Validate the request locally without sending. Great for debugging `--params`/`--json` shapes. |

Services (`gws <service> --help` for resources): `drive`, `sheets`, `docs`, `slides`, `gmail`, `calendar`, `tasks`, `people`, `chat`, `admin-reports`, `classroom`, `forms`, `keep`, `meet`, `events`, `script`, `workflow` (alias `wf`).

## Discovery: `gws schema`

When you do not know the request shape for a method, ask `gws` directly. This is the single most useful discovery move and beats grepping Google's HTML reference docs.

```bash
# Show the full schema for a single method
gws schema sheets.spreadsheets.values.batchUpdate

# Resolve nested $ref entries so the request body is fully expanded
gws schema docs.documents.batchUpdate --resolve-refs

# Pipe into jq to extract just the request body shape
gws schema gmail.users.messages.send | jq '.requestBody.schema.properties'
```

When in doubt, always run `gws schema <method>` *before* writing a `--json` payload by hand.

## Worked examples (most-used non-edit cases)

### Send a Gmail message

`gmail.users.messages.send` takes a base64url-encoded RFC 5322 message in the `raw` field:

```bash
RAW=$(printf 'To: someone@example.com\r\nFrom: me\r\nSubject: Hello from gws\r\n\r\nBody goes here.\r\n' \
  | base64 -w 0 | tr '+/' '-_' | tr -d '=')

gws gmail users messages send \
  --params '{"userId":"me"}' \
  --json "{\"raw\":\"${RAW}\"}"
```

For richer HTML mail, build the raw message with the appropriate `Content-Type: text/html; charset=UTF-8` header before base64-encoding.

### Create a calendar event

```bash
gws calendar events insert \
  --params '{"calendarId":"primary"}' \
  --json '{
    "summary": "Coffee with Mo",
    "description": "1:1 sync",
    "start": {"dateTime": "2026-05-28T10:00:00-07:00"},
    "end":   {"dateTime": "2026-05-28T10:30:00-07:00"},
    "attendees": [{"email": "mo@example.com"}]
  }'
```

List today's events:

```bash
gws calendar events list \
  --params '{"calendarId":"primary","singleEvents":true,"orderBy":"startTime","timeMin":"2026-05-27T00:00:00-07:00","timeMax":"2026-05-28T00:00:00-07:00"}' \
  --format table
```

### Add a Google Tasks entry

```bash
# Find your default task list ID
gws tasks tasklists list --format table

# Create a task on a list
TASKLIST_ID="MTIzNDU..."
gws tasks tasks insert \
  --params "{\"tasklist\":\"${TASKLIST_ID}\"}" \
  --json '{"title": "Review the IDP doc", "notes": "Due before standup", "due": "2026-05-28T00:00:00Z"}'
```

### Post a message into a Chat space

```bash
# Find the space name (spaces look like "spaces/AAAA...")
gws chat spaces list --format table

SPACE="spaces/AAAA..."
gws chat spaces messages create \
  --params "{\"parent\":\"${SPACE}\"}" \
  --json '{"text": "Heads up: rollout starts at 14:00 UTC."}'
```

### List or search Drive files (metadata only)

```bash
# Recent files
gws drive files list \
  --params '{"pageSize":20,"fields":"files(id,name,mimeType,modifiedTime,webViewLink)","orderBy":"modifiedTime desc"}' \
  --format table

# Search by name
gws drive files list \
  --params '{"q":"name contains '\''QBR'\''","fields":"files(id,name,modifiedTime)","pageSize":50}' \
  --page-all
```

For actually *editing* a Doc, Sheet, or Slides deck found via these listings, hand off to `gsuite-edit`.

## Bundled `+workflow` helpers

`gws workflow` (alias `gws wf`) ships ready-made productivity recipes that compose multiple API calls. Faster than building the same thing from primitives.

| Helper | What it does |
|---|---|
| `gws wf +standup-report` | Today's meetings + open tasks as a standup summary |
| `gws wf +meeting-prep`   | Prepare for your next meeting: agenda, attendees, linked docs |
| `gws wf +email-to-task`  | Convert a Gmail message into a Google Tasks entry |
| `gws wf +weekly-digest`  | This week's meetings + unread email count |
| `gws wf +file-announce`  | Announce a Drive file in a Chat space |

Each helper has its own `--help` (`gws wf +standup-report --help`). Common pattern is `gws wf +<name> --json '{...inputs...}'`.

## Environment knobs

The CLI reads these env vars (full list via `gws --help`):

| Var | Purpose |
|---|---|
| `GOOGLE_WORKSPACE_CLI_TOKEN` | Pre-obtained OAuth2 access token (highest priority, bypasses keyring). Useful for CI. |
| `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE` | Path to OAuth credentials JSON. |
| `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` | Override the default `~/.config/gws`. |
| `GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND` | `keyring` (default) or `file` for headless setups without a session keyring. |
| `GOOGLE_WORKSPACE_PROJECT_ID` | Override the GCP project for quota and billing. |
| `GOOGLE_WORKSPACE_CLI_LOG` | Log level for stderr (e.g. `gws=debug`). |
| `GOOGLE_WORKSPACE_CLI_LOG_FILE` | Directory for JSON log files (daily rotation). |

## Common errors and fixes

| Error | Cause | Fix |
|---|---|---|
| `auth_method: none` from `gws auth status` | Credentials not stored | Run `gws auth login`. If first time on machine, run `gws auth setup` first. |
| `Request had insufficient authentication scopes` (403) | The consent screen used by `gws auth setup` does not include the scope this method needs | Edit OAuth consent in GCP to add the scope, then `gws auth logout && gws auth login` |
| `Method doesn't allow unregistered callers` | Quota project not set | Either `gcloud config set project <id>` (gws picks it up) or `export GOOGLE_WORKSPACE_PROJECT_ID=<id>` |
| `keyring: not provided by any backend` | Headless machine without a session keyring (servers, containers) | `export GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file` and re-login; credentials land in an encrypted file under `~/.config/gws/` |
| `requestBody is required but was empty` | Forgot `--json '{...}'` on a POST/PATCH | Add `--json`; use `gws schema <method> --resolve-refs` to find the required fields |
| Hard to read a long JSON response | Default `--format` is `json` (one big line) | Pipe through `jq`, or use `--format table` / `--format yaml` for human reading |

For deeper per-service quickstarts (one-liner recipes per service), load `references/services.md`.
