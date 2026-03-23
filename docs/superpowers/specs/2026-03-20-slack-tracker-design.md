# Slack Tracker -- Design Spec

## Overview

A bash CLI tool that finds Slack messages you sent that either received no replies or where you were the last commenter in a thread. Authenticates via browser-extracted xoxc/xoxd tokens (no Slack app install required). Uses gum for interactive TUI, supports keyword highlighting, auto-tagging, and opening selected messages in browser tabs.

**Note:** Slack search (`search.messages`) requires a paid workspace plan.

## Module Structure

```
modules/apps/cli/slack-tracker/
├── default.nix              # NixOS module, writeShellApplication, runtimeInputs
├── scripts/
│   ├── slack-tracker.sh     # Main entrypoint (arg parsing, orchestration)
│   ├── lib-api.sh           # Slack API calls (search, replies, auth.test)
│   ├── lib-ui.sh            # Gum interactions (spinners, selects, tables, highlights)
│   └── lib-token.sh         # Credential management (CDP, launch, manual, validation)
└── docs/
    └── manual-token-guide.md  # How-to for manual token extraction from Chrome DevTools
```

### Nix Integration

- `default.nix`: `writeShellApplication` with `runtimeInputs` for `curl`, `jq`, `gum`, `google-chrome`, `xdg-utils`, `coreutils`, `gnugrep`, `gnused`
- Lib scripts inlined via `builtins.readFile` (same pattern as worktree-flow)
- `mkEnableOption "slack-tracker"` -- standard NixOS module under `apps.cli.slack-tracker`, added to `environment.systemPackages`

### Runtime Config/Data Locations

- `~/.config/slack-tracker/credentials.json` -- workspace tokens (xoxc + xoxd only, no config)
- `~/.config/slack-tracker/config.json` -- highlights, tags, default workspace, default period

## Credential Management (`lib-token.sh`)

### Credentials File Format

```json
{
  "workspaces": {
    "myworkspace": {
      "xoxc": "xoxc-...",
      "xoxd": "xoxd-...",
      "url": "https://myworkspace.slack.com",
      "updated": "2026-03-20T12:00:00Z"
    }
  }
}
```

Default workspace is configured in `config.json` (single source of truth for all preferences).

### `slack-tracker refresh [--workspace name]` -- Three-Tier Cascade

**Tier 1 -- CDP auto-extract:**

- Check if `localhost:9222` is reachable (curl, short timeout)
- Query `http://localhost:9222/json` for available pages
- Find a page whose URL contains `app.slack.com` or the workspace URL
- If no Slack tab found, report and fall through to Tier 2
- Connect to the page's WebSocket via `websocat` or curl-based CDP
- `Runtime.evaluate` with JS expression:
  ```javascript
  JSON.parse(localStorage.localConfig_v2).teams[
    JSON.parse(localStorage.localConfig_v2).lastActiveTeamId
  ].token;
  ```
- `Network.enable` then `Network.getCookies` with domain `.slack.com` to extract the `d` cookie (xoxd- value)
- Validate via `auth.test`, write to credentials file

**Tier 2 -- Offer to launch Chrome with debug port:**

- `gum confirm "Launch Chrome with remote debugging to auto-extract tokens?"`
- If yes: `google-chrome --remote-debugging-port=9222 https://app.slack.com` in background
- Gum spinner polling `http://localhost:9222/json` for CDP readiness (~15s timeout)
- Wait for a Slack page to appear in the page list
- Run CDP extraction from Tier 1
- Validate, write

**Tier 3 -- Manual guide fallback:**

- Print concise step-by-step instructions with gum styling (sourced from `docs/manual-token-guide.md`)
- `gum input --placeholder "Paste your xoxc- token"`
- `gum input --placeholder "Paste your xoxd- cookie"` (masked)
- `gum input --placeholder "Workspace URL (e.g. https://myteam.slack.com)"`
- Validate via `auth.test` immediately
- On failure: show error and specific reason from API response, loop back
- On success: write to credentials file

### Startup Validation

Every run begins with `auth.test`. If it fails, print the error reason and prompt to run `slack-tracker refresh`.

## Core Logic (`lib-api.sh` + `slack-tracker.sh`)

### Message Discovery Algorithm

1. **Search** -- `search.messages` with `from:@me after:YYYY-MM-DD` query. Paginate via `page` parameter (Slack returns up to 100 per page with `count=100`).

2. **Classify each message:**
   - **No replies** -- `reply_count` is 0 or absent. Candidate.
   - **You're last commenter** -- `reply_count > 0`, fetch `conversations.replies` for the thread, check if last reply's `user` matches your user ID. Candidate.
   - **Skip** -- thread has replies and someone else replied after you.

3. **Enrich:**
   - Channel name from `search.messages` response (already included as `channel.name` -- no extra API call needed)
   - Your user ID (fetched once via `auth.test` at startup)
   - Permalink from search response
   - Timestamp converted to human-readable date via `date -d @<ts>`

### Period Parsing

`--period <N><unit>` where unit is `d` (days), `w` (weeks), `m` (months):

- Convert to days: `d` = N, `w` = N*7, `m` = N*30
- Compute start date: `date -d "<days> days ago" +%Y-%m-%d`
- Pass to Slack search as `after:YYYY-MM-DD`

### Rate Limiting

- `search.messages`: Tier 2 (~20 req/min)
- `conversations.replies`: Tier 3 (~50 req/min)
- Gum spinner with progress count ("Checking message 14/87...")
- On `429` response: sleep for `Retry-After` header value (max 3 retries per request, then warn and skip)
- On network error: warn and abort with non-zero exit

### CLI Interface

```
slack-tracker [command] [options]

Commands:
  search     Search for unanswered messages (default if omitted)
  refresh    Refresh workspace tokens

Search options:
  --period <N><d|w|m>     Time window (default: gum chooser with presets)
  --workspace <name>      Override default workspace
  --tag <name>            Filter results to a specific tag
  --highlight <words>     Additional highlight words (comma-separated)
  --open-all              Open all results in browser tabs
  --list                  Non-interactive, tab-separated output to stdout
  --json                  Non-interactive, JSON output to stdout
  --verbose               Print API request/response details to stderr
```

Running `slack-tracker` with no arguments is equivalent to `slack-tracker search` (interactive mode).

### Internal Data Structure

```json
{
  "messages": [
    {
      "channel": "#engineering",
      "channel_id": "C123",
      "text": "Has anyone looked at the deploy failure?",
      "date": "2026-03-15",
      "permalink": "https://myworkspace.slack.com/archives/C123/p1710...",
      "type": "no_reply|last_commenter",
      "tags": ["deploy", "urgent"],
      "highlights": ["deploy"]
    }
  ]
}
```

## UI & Interaction (`lib-ui.sh`)

### Interactive Flow (default)

1. **Period selection** (if no `--period`):
   - `gum choose` with presets: "1 week" "2 weeks" "3 weeks" "1 month" "2 months" "3 months" "Custom"
   - Custom triggers `gum input --placeholder "e.g. 5d, 4w, 6m"`

2. **Fetching** -- `gum spin` wrapping API calls. Progress updates via stderr.

3. **Results display:**
   - Summary header: "Found 12 unanswered messages in the last 2 weeks"
   - If zero results: "No unanswered messages found in the last 2 weeks" and exit cleanly
   - Styled list per result:
     ```
     #engineering  2026-03-15  [urgent] [deploy]
     Has anyone looked at the deploy failure?
     -- no replies --
     ```
   - Highlighted words get ANSI color via gum
   - Tags shown as `[tagname]` badges
   - Type: "no replies" vs "awaiting response"

4. **Tag filtering** (if tags exist and no `--tag` flag):
   - `gum filter` showing unique tags in results, plus "All" option
   - "All" skips filtering

5. **Selection:**
   - `gum choose --no-limit` (multi-select) with channel + date + preview
   - Enter opens selected permalinks in browser

### Non-Interactive Modes

**`--list`:**

- Tab-separated: `date\tchannel\ttype\ttags\tpermalink\tpreview`
- No gum, no color
- Highlights rendered as `**word**`

**`--json`:**

- Outputs the internal JSON data structure directly
- Useful for piping to `jq` or other tools

### Browser Opening

- Batch URLs into a single `google-chrome` invocation: `google-chrome <url1> <url2> ...`
- Falls back to `xdg-open` per-URL with 200ms delay if Chrome invocation fails

## Config, Highlights & Tagging

### Config File (`~/.config/slack-tracker/config.json`)

```json
{
  "default_workspace": "myworkspace",
  "default_period": "2w",
  "highlights": ["deploy", "outage", "blocking", "urgent"],
  "tags": {
    "infra": ["deploy", "pipeline", "terraform", "k8s"],
    "urgent": ["outage", "blocking", "down", "broken"],
    "review": ["review", "PR", "approve", "feedback"]
  }
}
```

### Tagging Behavior

- Case-insensitive keyword scan against each tag's word list
- Messages can have multiple tags
- Tags are local classification only -- no Slack modification
- `--tag infra` filters results to matching messages

### Highlighting Behavior

- Config `highlights` array + CLI `--highlight` merged for each run
- Interactive: ANSI color on matched words
- `--list` mode: `**word**` wrapping

### First Run

- Missing config: create default with empty highlights/tags and no default workspace
- Missing credentials: auto-trigger `refresh` flow
- Gum-styled welcome message
