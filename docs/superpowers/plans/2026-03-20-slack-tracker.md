# Slack Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a bash CLI tool that finds unanswered Slack messages using browser-extracted tokens, with gum-powered interactive TUI, keyword highlighting, tagging, and browser opening.

**Architecture:** NixOS module at `modules/apps/cli/slack-tracker/` using `writeShellApplication`. Four bash files: main entrypoint + three libraries (api, ui, token). Authenticates via xoxc/xoxd browser tokens stored in `~/.config/slack-tracker/`. Uses CDP cascade for token refresh.

**Tech Stack:** Bash, curl, jq, gum, google-chrome, xdg-utils

**Spec:** `docs/superpowers/specs/2026-03-20-slack-tracker-design.md`

---

### File Structure

| File                                                        | Responsibility                                                                              |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `modules/apps/cli/slack-tracker/default.nix`                | NixOS module: mkEnableOption, writeShellApplication, runtimeInputs, inlines all scripts     |
| `modules/apps/cli/slack-tracker/scripts/slack-tracker.sh`   | Main entrypoint: arg parsing, config loading, command dispatch                              |
| `modules/apps/cli/slack-tracker/scripts/lib-token.sh`       | Token management: CDP extract, Chrome launch, manual paste, auth.test validation            |
| `modules/apps/cli/slack-tracker/scripts/lib-api.sh`         | Slack API: search.messages, conversations.replies, pagination, rate limiting                |
| `modules/apps/cli/slack-tracker/scripts/lib-ui.sh`          | TUI: gum period chooser, results display, highlighting, tagging, multi-select, browser open |
| `modules/apps/cli/slack-tracker/docs/manual-token-guide.md` | Step-by-step Chrome DevTools token extraction guide                                         |

---

### Task 1: Nix Module Skeleton

**Files:**

- Create: `modules/apps/cli/slack-tracker/default.nix`

- [ ] **Step 1: Create the module directory structure**

```bash
mkdir -p modules/apps/cli/slack-tracker/scripts
mkdir -p modules/apps/cli/slack-tracker/docs
```

- [ ] **Step 2: Create placeholder scripts**

Create empty placeholder files so the module can reference them:

`modules/apps/cli/slack-tracker/scripts/lib-token.sh`:

```bash
# lib-token.sh — credential management
# Sourced (inlined) by writeShellApplication, not executed directly
```

`modules/apps/cli/slack-tracker/scripts/lib-api.sh`:

```bash
# lib-api.sh — Slack API calls
# Sourced (inlined) by writeShellApplication, not executed directly
```

`modules/apps/cli/slack-tracker/scripts/lib-ui.sh`:

```bash
# lib-ui.sh — gum TUI interactions
# Sourced (inlined) by writeShellApplication, not executed directly
```

`modules/apps/cli/slack-tracker/scripts/slack-tracker.sh`:

```bash
# slack-tracker.sh — main entrypoint

usage() {
  cat <<'EOF'
Usage: slack-tracker [command] [options]

Commands:
  search     Search for unanswered messages (default)
  refresh    Refresh workspace tokens

Search options:
  --period <N><d|w|m>     Time window (e.g. 2w, 1m, 5d)
  --workspace <name>      Override default workspace
  --tag <name>            Filter results to a specific tag
  --highlight <words>     Additional highlight words (comma-separated)
  --open-all              Open all results in browser tabs
  --list                  Non-interactive tab-separated output
  --json                  Non-interactive JSON output
  --verbose               Print API details to stderr
  -h, --help              Show this help

Refresh options:
  --workspace <name>      Which workspace to refresh tokens for
EOF
}

main() {
  local command="search"

  if [[ $# -gt 0 ]]; then
    case "$1" in
      search|refresh) command="$1"; shift ;;
      -h|--help) usage; exit 0 ;;
      -*) ;; # flags handled later
      *) printf 'Unknown command: %s\n' "$1" >&2; usage >&2; exit 1 ;;
    esac
  fi

  case "$command" in
    search)  cmd_search "$@" ;;
    refresh) cmd_refresh "$@" ;;
  esac
}

cmd_search() {
  printf 'search not yet implemented\n'
}

cmd_refresh() {
  printf 'refresh not yet implemented\n'
}

main "$@"
```

- [ ] **Step 3: Create default.nix**

`modules/apps/cli/slack-tracker/default.nix`:

```nix
{ lib, pkgs, config, ... }:

let
  cfg = config.apps.cli.slack-tracker;

  libTokenSh = builtins.readFile ./scripts/lib-token.sh;
  libApiSh = builtins.readFile ./scripts/lib-api.sh;
  libUiSh = builtins.readFile ./scripts/lib-ui.sh;

  slack-tracker = pkgs.writeShellApplication {
    name = "slack-tracker";
    runtimeInputs = with pkgs; [
      curl
      jq
      gum
      google-chrome
      xdg-utils
      coreutils
      gnugrep
      gnused
    ];
    text = ''
      ${libTokenSh}
      ${libApiSh}
      ${libUiSh}
      ${builtins.readFile ./scripts/slack-tracker.sh}
    '';
  };
in
{
  options.apps.cli.slack-tracker.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable slack-tracker CLI tool for finding unanswered Slack messages.";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ slack-tracker ];
  };
}
```

- [ ] **Step 4: Enable the module in host config**

Find the host config file (likely `hosts/donkeykong/default.nix` or similar) and add:

```nix
apps.cli.slack-tracker.enable = true;
```

- [ ] **Step 5: Verify module builds**

```bash
just qr
```

Expected: clean build, `slack-tracker --help` prints usage.

- [ ] **Step 6: Commit**

```
feat(slack-tracker): scaffold module with CLI skeleton
```

---

### Task 2: Config & Credentials File Management

**Files:**

- Modify: `modules/apps/cli/slack-tracker/scripts/slack-tracker.sh`

- [ ] **Step 1: Add config directory and file initialization to slack-tracker.sh**

Add these functions to `slack-tracker.sh` before `main()`:

```bash
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/slack-tracker"
CONFIG_FILE="${CONFIG_DIR}/config.json"
CREDENTIALS_FILE="${CONFIG_DIR}/credentials.json"

ensure_config_dir() {
  mkdir -p "$CONFIG_DIR"
}

ensure_config() {
  ensure_config_dir
  if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" <<'DEFAULTCFG'
{
  "default_workspace": "",
  "default_period": "2w",
  "highlights": [],
  "tags": {}
}
DEFAULTCFG
    gum style --bold --foreground 33 "Welcome to slack-tracker!"
    gum style --foreground 240 "Created default config at ${CONFIG_FILE}"
    gum style --foreground 240 "Run 'slack-tracker refresh' to set up your Slack credentials."
  fi
}

load_config() {
  ensure_config
  DEFAULT_WORKSPACE="$(jq -r '.default_workspace // ""' "$CONFIG_FILE")"
  DEFAULT_PERIOD="$(jq -r '.default_period // "2w"' "$CONFIG_FILE")"
  HIGHLIGHTS_JSON="$(jq -c '.highlights // []' "$CONFIG_FILE")"
  TAGS_JSON="$(jq -c '.tags // {}' "$CONFIG_FILE")"
}

get_credentials() {
  local workspace="$1"
  if [[ ! -f "$CREDENTIALS_FILE" ]]; then
    return 1
  fi
  local xoxc xoxd url
  xoxc="$(jq -r --arg ws "$workspace" '.workspaces[$ws].xoxc // ""' "$CREDENTIALS_FILE")"
  xoxd="$(jq -r --arg ws "$workspace" '.workspaces[$ws].xoxd // ""' "$CREDENTIALS_FILE")"
  url="$(jq -r --arg ws "$workspace" '.workspaces[$ws].url // ""' "$CREDENTIALS_FILE")"
  if [[ -z "$xoxc" || -z "$xoxd" ]]; then
    return 1
  fi
  SLACK_XOXC="$xoxc"
  SLACK_XOXD="$xoxd"
  SLACK_URL="$url"
}

save_credentials() {
  local workspace="$1" xoxc="$2" xoxd="$3" url="$4"
  ensure_config_dir
  local now
  now="$(date -Iseconds)"
  if [[ ! -f "$CREDENTIALS_FILE" ]]; then
    printf '{"workspaces":{}}\n' > "$CREDENTIALS_FILE"
  fi
  local updated
  updated="$(jq \
    --arg ws "$workspace" \
    --arg xoxc "$xoxc" \
    --arg xoxd "$xoxd" \
    --arg url "$url" \
    --arg now "$now" \
    '.workspaces[$ws] = {xoxc: $xoxc, xoxd: $xoxd, url: $url, updated: $now}' \
    "$CREDENTIALS_FILE")"
  printf '%s\n' "$updated" > "$CREDENTIALS_FILE"
  chmod 600 "$CREDENTIALS_FILE"
}
```

- [ ] **Step 2: Wire config loading into main()**

Update `main()` to call `load_config` at the start:

```bash
main() {
  load_config

  local command="search"
  # ... rest unchanged
}
```

- [ ] **Step 3: Test config creation**

```bash
just qr
```

Then run:

```bash
rm -rf ~/.config/slack-tracker
slack-tracker
```

Expected: welcome message, config.json created with defaults, error about missing credentials.

- [ ] **Step 4: Commit**

```
feat(slack-tracker): add config and credentials file management
```

---

### Task 3: Token Refresh -- Manual Flow (Tier 3)

**Files:**

- Modify: `modules/apps/cli/slack-tracker/scripts/lib-token.sh`
- Modify: `modules/apps/cli/slack-tracker/scripts/slack-tracker.sh`
- Create: `modules/apps/cli/slack-tracker/docs/manual-token-guide.md`

- [ ] **Step 1: Write the manual token guide**

`modules/apps/cli/slack-tracker/docs/manual-token-guide.md`:

````markdown
# Manual Slack Token Extraction (Chrome)

## Get the xoxc- token

1. Open Chrome and go to your Slack workspace (https://app.slack.com)
2. Open DevTools: F12 or Ctrl+Shift+I
3. Go to the Console tab
4. Paste this and press Enter:

   ```javascript
   JSON.parse(localStorage.localConfig_v2).teams[
     JSON.parse(localStorage.localConfig_v2).lastActiveTeamId
   ].token;
   ```
````

5. Copy the `xoxc-...` value (without quotes)

## Get the xoxd- cookie

1. In DevTools, go to Application tab
2. In the sidebar: Storage > Cookies > https://app.slack.com
3. Find the cookie named `d`
4. Copy its Value (starts with `xoxd-`)

## Workspace URL

Your workspace URL looks like: `https://yourteam.slack.com`

````

- [ ] **Step 2: Implement auth_test and manual refresh in lib-token.sh**

```bash
# lib-token.sh — credential management

VERBOSE="${VERBOSE:-false}"

slack_auth_test() {
  local xoxc="$1" xoxd="$2"
  local response
  response="$(curl -fsSL \
    -H "Authorization: Bearer ${xoxc}" \
    -H "Cookie: d=${xoxd}" \
    "https://slack.com/api/auth.test" 2>/dev/null)" || return 1

  local ok
  ok="$(printf '%s' "$response" | jq -r '.ok')"
  if [[ "$ok" != "true" ]]; then
    local error
    error="$(printf '%s' "$response" | jq -r '.error // "unknown error"')"
    if [[ "$VERBOSE" == "true" ]]; then
      gum log --level error "auth.test failed: ${error}" >&2
    fi
    return 1
  fi
  printf '%s' "$response"
}

validate_and_save_tokens() {
  local workspace="$1" xoxc="$2" xoxd="$3" url="$4"

  gum spin --title "Validating tokens..." -- sleep 0.5
  local auth_response
  if ! auth_response="$(slack_auth_test "$xoxc" "$xoxd")"; then
    gum log --level error "Token validation failed. Please check your tokens and try again." >&2
    return 1
  fi

  local user team
  user="$(printf '%s' "$auth_response" | jq -r '.user')"
  team="$(printf '%s' "$auth_response" | jq -r '.team')"
  save_credentials "$workspace" "$xoxc" "$xoxd" "$url"
  gum style --bold --foreground 46 "Authenticated as ${user} in ${team}"
  gum style --foreground 240 "Credentials saved to ${CREDENTIALS_FILE}"
}

refresh_manual() {
  local workspace="$1"

  gum style --bold --foreground 33 "Manual Token Extraction"
  gum style ""
  gum style --foreground 240 "Follow these steps in Chrome DevTools on your Slack tab:"
  gum style ""
  gum style "1. Open Chrome DevTools (F12) on app.slack.com"
  gum style "2. Console tab → paste the JS snippet below → copy the xoxc- token"
  gum style --foreground 220 '   JSON.parse(localStorage.localConfig_v2).teams[JSON.parse(localStorage.localConfig_v2).lastActiveTeamId].token'
  gum style "3. Application tab → Cookies → app.slack.com → copy the 'd' cookie value (xoxd-)"
  gum style ""

  local xoxc xoxd url
  while true; do
    xoxc="$(gum input --placeholder "Paste your xoxc- token" --width 80)"
    if [[ -z "$xoxc" ]]; then
      gum log --level error "Token cannot be empty" >&2
      continue
    fi
    if [[ "$xoxc" != xoxc-* ]]; then
      gum log --level warn "Token doesn't start with 'xoxc-' — are you sure it's correct?" >&2
      if ! gum confirm "Use this token anyway?"; then
        continue
      fi
    fi
    break
  done

  while true; do
    xoxd="$(gum input --placeholder "Paste your xoxd- cookie" --width 80 --password)"
    if [[ -z "$xoxd" ]]; then
      gum log --level error "Cookie cannot be empty" >&2
      continue
    fi
    break
  done

  if [[ -z "$url" ]]; then
    url="$(gum input --placeholder "Workspace URL (e.g. https://myteam.slack.com)" --width 60)"
  fi

  if ! validate_and_save_tokens "$workspace" "$xoxc" "$xoxd" "$url"; then
    gum log --level error "Validation failed. Try again." >&2
    if gum confirm "Retry manual entry?"; then
      refresh_manual "$workspace"
    fi
    return 1
  fi
}
````

- [ ] **Step 3: Wire up cmd_refresh in slack-tracker.sh**

Replace the `cmd_refresh` stub:

```bash
cmd_refresh() {
  local workspace="${WORKSPACE_OVERRIDE:-$DEFAULT_WORKSPACE}"

  # Parse refresh-specific flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --workspace) workspace="$2"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$workspace" ]]; then
    workspace="$(gum input --placeholder "Workspace name (e.g. myteam)" --width 40)"
    if [[ -z "$workspace" ]]; then
      gum log --level error "Workspace name is required" >&2
      exit 1
    fi
  fi

  # Tier 1: Try CDP auto-extract
  if refresh_cdp "$workspace"; then
    return 0
  fi

  # Tier 2: Offer to launch Chrome
  if refresh_launch_chrome "$workspace"; then
    return 0
  fi

  # Tier 3: Manual fallback
  refresh_manual "$workspace"
}
```

- [ ] **Step 4: Add stub CDP functions to lib-token.sh**

Add these stubs (implemented in Task 4):

```bash
refresh_cdp() {
  # Tier 1: CDP auto-extract — implemented in Task 4
  return 1
}

refresh_launch_chrome() {
  # Tier 2: Launch Chrome with debug port — implemented in Task 4
  return 1
}
```

- [ ] **Step 5: Test manual refresh flow**

```bash
just qr && slack-tracker refresh --workspace testworkspace
```

Expected: shows manual guide, prompts for token + cookie + URL, validates via auth.test, saves to credentials.json.

- [ ] **Step 6: Commit**

```
feat(slack-tracker): add manual token refresh with auth.test validation
```

---

### Task 4: Token Refresh -- CDP Auto-Extract (Tiers 1 & 2)

> **Note:** Full WebSocket-based CDP extraction is impractical in pure bash (requires `websocat` or similar). This implementation uses a pragmatic approach: if an existing xoxd cookie is on file, it scrapes the xoxc token from Slack's page source using the cookie. For truly fresh setups, Tiers 1 & 2 will fall through to Tier 3 (manual). This is acceptable since manual entry is fast and tokens last weeks/months.

**Files:**

- Modify: `modules/apps/cli/slack-tracker/scripts/lib-token.sh`

- [ ] **Step 1: Implement CDP helper functions**

Replace the `refresh_cdp` and `refresh_launch_chrome` stubs in `lib-token.sh`:

```bash
cdp_check_available() {
  curl -fsSL --max-time 2 "http://localhost:9222/json" >/dev/null 2>&1
}

cdp_find_slack_page() {
  local pages
  pages="$(curl -fsSL --max-time 5 "http://localhost:9222/json" 2>/dev/null)" || return 1
  # Find a page with slack.com in the URL
  local ws_url
  ws_url="$(printf '%s' "$pages" | jq -r '[.[] | select(.url | test("slack\\.com"))] | .[0].webSocketDebuggerUrl // ""')"
  if [[ -z "$ws_url" ]]; then
    return 1
  fi
  printf '%s' "$ws_url"
}

cdp_extract_tokens() {
  local ws_url="$1"

  # Extract xoxc token via Runtime.evaluate
  local eval_payload
  eval_payload='{"id":1,"method":"Runtime.evaluate","params":{"expression":"JSON.parse(localStorage.localConfig_v2).teams[JSON.parse(localStorage.localConfig_v2).lastActiveTeamId].token"}}'

  local eval_response
  eval_response="$(printf '%s' "$eval_payload" | curl -fsSL --max-time 10 \
    --include \
    -H "Connection: Upgrade" \
    -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: $(head -c 16 /dev/urandom | base64)" \
    "$ws_url" \
    --data-binary @- 2>/dev/null)" || return 1

  # Note: raw WebSocket via curl is unreliable. Use websocat if available, else fall through.
  # Simplified approach: use the /json/evaluate endpoint pattern or fall through to manual
  return 1
}

cdp_extract_via_page_source() {
  local workspace="$1" xoxd="$2"
  # Alternative: fetch xoxc from the page HTML using the d cookie
  local page_html xoxc
  page_html="$(curl -fsSL --max-time 15 \
    --cookie "d=${xoxd}" \
    "https://app.slack.com" 2>/dev/null)" || return 1
  xoxc="$(printf '%s' "$page_html" | grep -oE 'xoxc-[a-zA-Z0-9-]+' | head -1)"
  if [[ -z "$xoxc" ]]; then
    return 1
  fi
  printf '%s' "$xoxc"
}

cdp_extract_cookie() {
  local ws_url="$1"
  # CDP Network.getCookies requires WebSocket — complex in pure bash
  # Fall through to page-source approach or manual
  return 1
}

refresh_cdp() {
  local workspace="$1"

  if ! cdp_check_available; then
    [[ "$VERBOSE" == "true" ]] && gum log --level debug "CDP not available on :9222" >&2
    return 1
  fi

  gum log --level info "Detected Chrome remote debugging on :9222" >&2

  local ws_url
  if ! ws_url="$(cdp_find_slack_page)"; then
    gum log --level warn "No Slack tab found in Chrome" >&2
    return 1
  fi

  gum spin --title "Extracting tokens via CDP..." -- sleep 1

  # CDP WebSocket in pure bash is fragile. If we have existing xoxd, try page-source method.
  local existing_xoxd=""
  if [[ -f "$CREDENTIALS_FILE" ]]; then
    existing_xoxd="$(jq -r --arg ws "$workspace" '.workspaces[$ws].xoxd // ""' "$CREDENTIALS_FILE" 2>/dev/null)"
  fi

  if [[ -n "$existing_xoxd" ]]; then
    local xoxc
    if xoxc="$(cdp_extract_via_page_source "$workspace" "$existing_xoxd")"; then
      local url
      url="$(jq -r --arg ws "$workspace" '.workspaces[$ws].url // ""' "$CREDENTIALS_FILE")"
      if validate_and_save_tokens "$workspace" "$xoxc" "$existing_xoxd" "$url"; then
        return 0
      fi
    fi
  fi

  gum log --level warn "CDP auto-extraction failed" >&2
  return 1
}

refresh_launch_chrome() {
  local workspace="$1"

  if ! gum confirm "Launch Chrome with remote debugging to auto-extract tokens?"; then
    return 1
  fi

  gum log --level info "Launching Chrome with remote debugging..." >&2
  google-chrome --remote-debugging-port=9222 "https://app.slack.com" &>/dev/null &
  local chrome_pid=$!

  # Wait for CDP to become available
  local attempts=0
  local max_attempts=15
  while ! cdp_check_available && [[ $attempts -lt $max_attempts ]]; do
    sleep 1
    ((attempts++))
  done

  if ! cdp_check_available; then
    gum log --level warn "Chrome didn't start remote debugging in time" >&2
    return 1
  fi

  # Wait a bit more for Slack to fully load
  gum spin --title "Waiting for Slack to load..." -- sleep 5

  # Try CDP extraction
  if refresh_cdp "$workspace"; then
    return 0
  fi

  gum log --level warn "Auto-extraction failed after launching Chrome" >&2
  return 1
}
```

- [ ] **Step 2: Test CDP flow**

Test with Chrome running with `--remote-debugging-port=9222`:

```bash
just qr && slack-tracker refresh --workspace myworkspace
```

Expected: detects CDP, attempts extraction, falls through to manual if needed.

- [ ] **Step 3: Commit**

```
feat(slack-tracker): add CDP and Chrome-launch token extraction tiers
```

---

### Task 5: Slack API -- Search & Classify Messages

**Files:**

- Modify: `modules/apps/cli/slack-tracker/scripts/lib-api.sh`

- [ ] **Step 1: Implement API call helpers**

```bash
# lib-api.sh — Slack API calls

SLACK_XOXC="${SLACK_XOXC:-}"
SLACK_XOXD="${SLACK_XOXD:-}"
MY_USER_ID=""

slack_api() {
  local endpoint="$1"
  shift
  local retries=0 max_retries=3

  if [[ "$VERBOSE" == "true" ]]; then
    gum log --level debug "API: ${endpoint}" >&2
  fi

  while true; do
    local header_file
    header_file="$(mktemp)"

    # Use -sS (not -f) so we can inspect HTTP status ourselves
    local response
    response="$(curl -sS -w '\n%{http_code}' \
      -D "$header_file" \
      -H "Authorization: Bearer ${SLACK_XOXC}" \
      -H "Cookie: d=${SLACK_XOXD}" \
      "https://slack.com/api/${endpoint}" "$@" 2>/dev/null)"

    local exit_code=$?
    local http_code
    http_code="$(printf '%s' "$response" | tail -1)"
    response="$(printf '%s' "$response" | sed '$d')"

    if [[ $exit_code -ne 0 ]]; then
      rm -f "$header_file"
      gum log --level error "Network error calling ${endpoint}" >&2
      return 1
    fi

    if [[ "$http_code" == "429" ]]; then
      ((retries++))
      if [[ $retries -gt $max_retries ]]; then
        rm -f "$header_file"
        gum log --level warn "Rate limited ${max_retries} times on ${endpoint}, skipping" >&2
        return 1
      fi
      # Read Retry-After from HTTP headers
      local retry_after
      retry_after="$(grep -i 'Retry-After' "$header_file" | tr -d '\r' | awk '{print $2}')"
      retry_after="${retry_after:-5}"
      rm -f "$header_file"
      gum log --level warn "Rate limited. Waiting ${retry_after}s (attempt ${retries}/${max_retries})..." >&2
      sleep "$retry_after"
      continue
    fi

    rm -f "$header_file"

    local ok
    ok="$(printf '%s' "$response" | jq -r '.ok' 2>/dev/null)"
    if [[ "$ok" != "true" ]]; then
      local error
      error="$(printf '%s' "$response" | jq -r '.error // "unknown"')"
      if [[ "$VERBOSE" == "true" ]]; then
        gum log --level error "API error (${endpoint}): ${error}" >&2
      fi
      return 1
    fi

    printf '%s' "$response"
    return 0
  done
}

get_my_user_id() {
  local response
  response="$(slack_api "auth.test")" || return 1
  MY_USER_ID="$(printf '%s' "$response" | jq -r '.user_id')"
}
```

- [ ] **Step 2: Implement search with pagination**

Add to `lib-api.sh`:

```bash
search_my_messages() {
  local after_date="$1"
  local query="from:@me after:${after_date}"
  local page=1
  local all_matches="[]"
  local total=0

  while true; do
    local response
    response="$(slack_api "search.messages?query=$(printf '%s' "$query" | jq -sRr @uri)&count=100&page=${page}&sort=timestamp&sort_dir=desc")" || return 1

    if [[ $page -eq 1 ]]; then
      total="$(printf '%s' "$response" | jq '.messages.total // 0')"
      if [[ "$total" -eq 0 ]]; then
        printf '[]'
        return 0
      fi
    fi

    local matches
    matches="$(printf '%s' "$response" | jq '.messages.matches // []')"
    all_matches="$(printf '%s' "$all_matches" | jq --argjson m "$matches" '. + $m')"

    local page_count
    page_count="$(printf '%s' "$response" | jq '.messages.paging.pages // 1')"
    if [[ $page -ge $page_count ]]; then
      break
    fi
    ((page++))
  done

  printf '%s' "$all_matches"
}
```

- [ ] **Step 3: Implement thread classification**

Add to `lib-api.sh`:

```bash
get_thread_last_reply_user() {
  local channel_id="$1" thread_ts="$2"
  local response
  # Fetch all replies (no limit) — conversations.replies is a GET endpoint
  response="$(slack_api "conversations.replies?channel=${channel_id}&ts=${thread_ts}")" || return 1

  # Get the last message in the thread (first element is the parent, so last is most recent reply)
  local last_user
  last_user="$(printf '%s' "$response" | jq -r '.messages | last | .user // ""')"
  printf '%s' "$last_user"
}

classify_messages() {
  local messages_json="$1"
  local total
  total="$(printf '%s' "$messages_json" | jq 'length')"
  local results="[]"
  local count=0

  while IFS= read -r msg; do
    ((count++))
    printf '\r  Checking message %d/%d...' "$count" "$total" >&2

    local channel channel_id text ts permalink reply_count
    channel="$(printf '%s' "$msg" | jq -r '.channel.name // "unknown"')"
    channel_id="$(printf '%s' "$msg" | jq -r '.channel.id // ""')"
    text="$(printf '%s' "$msg" | jq -r '.text // ""')"
    ts="$(printf '%s' "$msg" | jq -r '.ts // ""')"
    permalink="$(printf '%s' "$msg" | jq -r '.permalink // ""')"
    reply_count="$(printf '%s' "$msg" | jq -r '(.reply_count // 0) | tonumber')"

    local msg_type=""

    if [[ "$reply_count" -eq 0 ]]; then
      msg_type="no_reply"
    else
      local last_user
      if last_user="$(get_thread_last_reply_user "$channel_id" "$ts")"; then
        if [[ "$last_user" == "$MY_USER_ID" ]]; then
          msg_type="last_commenter"
        fi
      fi
    fi

    if [[ -n "$msg_type" ]]; then
      local date_str
      date_str="$(date -d "@${ts%.*}" +%Y-%m-%d 2>/dev/null || echo "unknown")"
      local entry
      entry="$(jq -n \
        --arg channel "#${channel}" \
        --arg channel_id "$channel_id" \
        --arg text "$text" \
        --arg date "$date_str" \
        --arg permalink "$permalink" \
        --arg type "$msg_type" \
        '{channel: $channel, channel_id: $channel_id, text: $text, date: $date, permalink: $permalink, type: $type, tags: [], highlights: []}')"
      results="$(printf '%s' "$results" | jq --argjson e "$entry" '. + [$e]')"
    fi
  done < <(printf '%s' "$messages_json" | jq -c '.[]')

  printf '\r%*s\r' 40 '' >&2  # Clear progress line
  printf '%s' "$results"
}
```

- [ ] **Step 4: Test API functions work with real tokens**

```bash
just qr
slack-tracker refresh --workspace myworkspace
# (manually enter tokens)
# Then test search will happen in Task 7 when wired up
```

- [ ] **Step 5: Commit**

```
feat(slack-tracker): implement Slack API search and thread classification
```

---

### Task 6: UI -- Period Selection, Results Display, Browser Opening

**Files:**

- Modify: `modules/apps/cli/slack-tracker/scripts/lib-ui.sh`

- [ ] **Step 1: Implement period parsing and selection**

```bash
# lib-ui.sh — gum TUI interactions

parse_period() {
  local period="$1"
  local num unit days
  num="$(printf '%s' "$period" | grep -oE '^[0-9]+')"
  unit="$(printf '%s' "$period" | grep -oE '[dwm]$')"

  if [[ -z "$num" || -z "$unit" ]]; then
    gum log --level error "Invalid period format: ${period}. Use <N><d|w|m> (e.g. 2w, 1m, 5d)" >&2
    return 1
  fi

  case "$unit" in
    d) days="$num" ;;
    w) days=$((num * 7)) ;;
    m) days=$((num * 30)) ;;
  esac

  date -d "${days} days ago" +%Y-%m-%d
}

choose_period() {
  local choice
  choice="$(gum choose \
    "1 week" "2 weeks" "3 weeks" \
    "1 month" "2 months" "3 months" \
    "Custom")"

  case "$choice" in
    "1 week")   echo "1w" ;;
    "2 weeks")  echo "2w" ;;
    "3 weeks")  echo "3w" ;;
    "1 month")  echo "1m" ;;
    "2 months") echo "2m" ;;
    "3 months") echo "3m" ;;
    "Custom")
      gum input --placeholder "e.g. 5d, 4w, 6m" --width 20
      ;;
    *) echo "2w" ;;
  esac
}
```

- [ ] **Step 2: Implement tagging and highlighting**

Add to `lib-ui.sh`:

```bash
apply_tags() {
  local messages_json="$1" tags_json="$2"
  if [[ "$tags_json" == "{}" || "$tags_json" == "null" ]]; then
    printf '%s' "$messages_json"
    return
  fi

  printf '%s' "$messages_json" | jq --argjson tags "$tags_json" '
    [.[] | . as $msg |
      .tags = ([
        $tags | to_entries[] |
        select(.value | any(. as $kw | $msg.text | ascii_downcase | contains($kw | ascii_downcase)))
      ] | map(.key))
    ]'
}

apply_highlights() {
  local messages_json="$1" highlights_json="$2"
  if [[ "$highlights_json" == "[]" || "$highlights_json" == "null" ]]; then
    printf '%s' "$messages_json"
    return
  fi

  printf '%s' "$messages_json" | jq --argjson hl "$highlights_json" '
    [.[] | . as $msg |
      .highlights = ([
        $hl[] | select(. as $kw | $msg.text | ascii_downcase | contains($kw | ascii_downcase))
      ])
    ]'
}
```

- [ ] **Step 3: Implement results display**

Add to `lib-ui.sh`:

```bash
display_results_interactive() {
  local messages_json="$1"
  local count
  count="$(printf '%s' "$messages_json" | jq 'length')"

  while IFS= read -r msg; do
    local channel date msg_type text tags_str highlights

    channel="$(printf '%s' "$msg" | jq -r '.channel')"
    date="$(printf '%s' "$msg" | jq -r '.date')"
    msg_type="$(printf '%s' "$msg" | jq -r '.type')"
    text="$(printf '%s' "$msg" | jq -r '.text' | head -c 120)"

    # Build tag badges
    tags_str="$(printf '%s' "$msg" | jq -r '.tags | map("[\(.)]) | join(" ")')"

    # Type label
    local type_label
    if [[ "$msg_type" == "no_reply" ]]; then
      type_label="$(gum style --foreground 196 "no replies")"
    else
      type_label="$(gum style --foreground 214 "awaiting response")"
    fi

    # Highlight matched words in text
    highlights="$(printf '%s' "$msg" | jq -r '.highlights[]' 2>/dev/null)"
    local display_text="$text"
    while IFS= read -r word; do
      [[ -z "$word" ]] && continue
      local styled
      styled="$(gum style --foreground 46 "${word}")"
      display_text="$(printf '%s' "$display_text" | sed "s/${word}/${styled}/gi" 2>/dev/null || printf '%s' "$display_text")"
    done <<< "$highlights"

    # Format: channel  date  [tags]
    local header
    header="$(gum style --bold "${channel}")  ${date}  ${tags_str}"
    printf '%s\n' "$header"
    printf '  %s\n' "$display_text"
    printf '  %s\n\n' "$type_label"
  done < <(printf '%s' "$messages_json" | jq -c '.[]')
}

display_results_list() {
  local messages_json="$1"
  # Tab-separated: date, channel, type, tags, permalink, preview (with **highlights**)
  printf '%s' "$messages_json" | jq -r '.[] |
    (.highlights // []) as $hl |
    (.text | gsub("\n"; " ") | .[0:100]) as $preview |
    (reduce $hl[] as $word ($preview; gsub("(?i)\($word)"; "**\($word)**"))) as $highlighted_preview |
    [.date, .channel, .type,
     (.tags | join(",")),
     .permalink,
     $highlighted_preview] | @tsv'
}

display_results_json() {
  local messages_json="$1"
  printf '%s' "$messages_json" | jq '.'
}
```

- [ ] **Step 4: Implement tag filtering and message selection**

Add to `lib-ui.sh`:

```bash
filter_by_tag_interactive() {
  local messages_json="$1"
  local unique_tags
  unique_tags="$(printf '%s' "$messages_json" | jq -r '[.[].tags[]] | unique | .[]')"

  if [[ -z "$unique_tags" ]]; then
    printf '%s' "$messages_json"
    return
  fi

  local selected_tag
  selected_tag="$(printf '%s\n%s' "All" "$unique_tags" | gum filter --header "Filter by tag (or All):" --placeholder "type to search...")"

  if [[ "$selected_tag" == "All" || -z "$selected_tag" ]]; then
    printf '%s' "$messages_json"
    return
  fi

  printf '%s' "$messages_json" | jq --arg tag "$selected_tag" '[.[] | select(.tags | index($tag))]'
}

select_messages_to_open() {
  local messages_json="$1"
  # Include index in display for reliable mapping, format: "[idx] date  channel  preview"
  local options
  options="$(printf '%s' "$messages_json" | jq -r 'to_entries[] |
    "[\(.key)] \(.value.date)  \(.value.channel)  \(.value.text | gsub("\n"; " ") | .[0:70])"')"

  if [[ -z "$options" ]]; then
    return 1
  fi

  local selected
  selected="$(printf '%s' "$options" | gum choose --no-limit --header "Select messages to open in browser:")"

  if [[ -z "$selected" ]]; then
    return 1
  fi

  # Extract index from "[idx]" prefix and map to permalink
  while IFS= read -r line; do
    local idx
    idx="$(printf '%s' "$line" | grep -oE '^\[[0-9]+\]' | tr -d '[]')"
    printf '%s' "$messages_json" | jq -r ".[$idx].permalink"
  done <<< "$selected"
}

open_in_browser() {
  local -a urls=()
  while IFS= read -r url; do
    [[ -z "$url" ]] && continue
    urls+=("$url")
  done

  if [[ ${#urls[@]} -eq 0 ]]; then
    return
  fi

  gum log --level info "Opening ${#urls[@]} message(s) in browser..." >&2

  # Try batch Chrome open first
  if google-chrome "${urls[@]}" 2>/dev/null; then
    return 0
  fi

  # Fallback: xdg-open one at a time
  for url in "${urls[@]}"; do
    xdg-open "$url" 2>/dev/null
    sleep 0.2
  done
}
```

- [ ] **Step 5: Commit**

```
feat(slack-tracker): implement TUI with period selection, results display, and browser opening
```

---

### Task 7: Wire Everything Together in Main Entrypoint

**Files:**

- Modify: `modules/apps/cli/slack-tracker/scripts/slack-tracker.sh`

- [ ] **Step 1: Implement cmd_search with full argument parsing**

Replace the `cmd_search` stub in `slack-tracker.sh`:

```bash
cmd_search() {
  local period="" workspace="" tag_filter="" extra_highlights="" open_all=false list_mode=false json_mode=false

  workspace="${WORKSPACE_OVERRIDE:-$DEFAULT_WORKSPACE}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --period)     period="$2"; shift 2 ;;
      --workspace)  workspace="$2"; shift 2 ;;
      --tag)        tag_filter="$2"; shift 2 ;;
      --highlight)  extra_highlights="$2"; shift 2 ;;
      --open-all)   open_all=true; shift ;;
      --list)       list_mode=true; shift ;;
      --json)       json_mode=true; shift ;;
      --verbose)    VERBOSE=true; shift ;;
      -h|--help)    usage; exit 0 ;;
      *)            printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
    esac
  done

  # Resolve workspace
  if [[ -z "$workspace" ]]; then
    if [[ "$list_mode" == "true" || "$json_mode" == "true" ]]; then
      printf 'Error: --workspace required in non-interactive mode (no default set)\n' >&2
      exit 1
    fi
    workspace="$(gum input --placeholder "Workspace name" --width 40)"
  fi

  # Load credentials — auto-trigger refresh if missing (per spec first-run flow)
  if ! get_credentials "$workspace"; then
    gum log --level warn "No credentials for workspace '${workspace}'." >&2
    if [[ "$list_mode" == "true" || "$json_mode" == "true" ]]; then
      gum log --level error "Run: slack-tracker refresh --workspace ${workspace}" >&2
      exit 1
    fi
    if gum confirm "Set up credentials for '${workspace}' now?"; then
      cmd_refresh --workspace "$workspace"
      if ! get_credentials "$workspace"; then
        gum log --level error "Credentials still missing after refresh." >&2
        exit 1
      fi
    else
      exit 1
    fi
  fi

  # Validate auth
  if ! get_my_user_id; then
    gum log --level error "Token expired or invalid. Run: slack-tracker refresh --workspace ${workspace}" >&2
    exit 1
  fi

  # Resolve period
  if [[ -z "$period" ]]; then
    if [[ "$list_mode" == "true" || "$json_mode" == "true" ]]; then
      period="$DEFAULT_PERIOD"
    else
      period="$(choose_period)"
    fi
  fi

  local after_date
  after_date="$(parse_period "$period")" || exit 1

  # Merge highlights
  local merged_highlights="$HIGHLIGHTS_JSON"
  if [[ -n "$extra_highlights" ]]; then
    local extra_json
    extra_json="$(printf '%s' "$extra_highlights" | jq -R 'split(",")')"
    merged_highlights="$(printf '%s' "$merged_highlights" | jq --argjson extra "$extra_json" '. + $extra | unique')"
  fi

  # Search
  gum log --level info "Searching for unanswered messages since ${after_date}..." >&2
  local raw_messages
  raw_messages="$(search_my_messages "$after_date")" || {
    gum log --level error "Search failed" >&2
    exit 1
  }

  local raw_count
  raw_count="$(printf '%s' "$raw_messages" | jq 'length')"
  if [[ "$raw_count" -eq 0 ]]; then
    gum style --foreground 240 "No messages found in the last ${period}."
    exit 0
  fi

  gum log --level info "Found ${raw_count} messages. Checking threads..." >&2

  # Classify
  local classified
  classified="$(classify_messages "$raw_messages")"

  local result_count
  result_count="$(printf '%s' "$classified" | jq 'length')"
  if [[ "$result_count" -eq 0 ]]; then
    gum style --foreground 240 "No unanswered messages found in the last ${period}."
    exit 0
  fi

  # Apply tags and highlights
  classified="$(apply_tags "$classified" "$TAGS_JSON")"
  classified="$(apply_highlights "$classified" "$merged_highlights")"

  # Apply tag filter
  if [[ -n "$tag_filter" ]]; then
    classified="$(printf '%s' "$classified" | jq --arg tag "$tag_filter" '[.[] | select(.tags | index($tag))]')"
    result_count="$(printf '%s' "$classified" | jq 'length')"
    if [[ "$result_count" -eq 0 ]]; then
      gum style --foreground 240 "No messages matching tag '${tag_filter}'."
      exit 0
    fi
  fi

  # Output
  if [[ "$json_mode" == "true" ]]; then
    display_results_json "$classified"
    return
  fi

  if [[ "$list_mode" == "true" ]]; then
    display_results_list "$classified"
    return
  fi

  # Interactive mode
  gum style --bold "Found ${result_count} unanswered messages (last ${period})"
  printf '\n'

  # Optional tag filter (interactive)
  if [[ -z "$tag_filter" ]]; then
    classified="$(filter_by_tag_interactive "$classified")"
    result_count="$(printf '%s' "$classified" | jq 'length')"
  fi

  display_results_interactive "$classified"

  # Open in browser
  if [[ "$open_all" == "true" ]]; then
    printf '%s' "$classified" | jq -r '.[].permalink' | open_in_browser
  else
    if gum confirm "Open selected messages in browser?"; then
      select_messages_to_open "$classified" | open_in_browser
    fi
  fi
}
```

- [ ] **Step 2: Update main() to handle global --verbose flag**

```bash
main() {
  load_config

  local command="search"
  VERBOSE="${VERBOSE:-false}"
  WORKSPACE_OVERRIDE=""

  # Pre-scan for global flags
  local args=()
  for arg in "$@"; do
    case "$arg" in
      --verbose) VERBOSE=true ;;
      *) args+=("$arg") ;;
    esac
  done
  set -- "${args[@]}"

  if [[ $# -gt 0 ]]; then
    case "$1" in
      search|refresh) command="$1"; shift ;;
      -h|--help) usage; exit 0 ;;
      -*) ;; # flags handled by subcommand
      *) printf 'Unknown command: %s\n' "$1" >&2; usage >&2; exit 1 ;;
    esac
  fi

  case "$command" in
    search)  cmd_search "$@" ;;
    refresh) cmd_refresh "$@" ;;
  esac
}
```

- [ ] **Step 3: Rebuild and test end-to-end**

```bash
just qr
```

Test interactive:

```bash
slack-tracker --period 1w
```

Test non-interactive:

```bash
slack-tracker --list --period 2w --workspace myworkspace
slack-tracker --json --period 1w --workspace myworkspace
```

- [ ] **Step 4: Commit**

```
feat(slack-tracker): wire up search command with full interactive flow
```

---

### Task 8: Final Polish & Docs

**Files:**

- All scripts (minor fixes from testing)

- [ ] **Step 1: Test the complete refresh cascade**

```bash
slack-tracker refresh --workspace myworkspace
```

Verify all three tiers cascade correctly.

- [ ] **Step 2: Test edge cases**

- Empty search results
- Very long message text (truncation)
- Workspace with no credentials
- Invalid period format
- `--open-all` with multiple results
- `--tag` filter that matches nothing

- [ ] **Step 3: Run nix fmt and statix**

```bash
nix fmt
statix check modules/apps/cli/slack-tracker/
deadnix modules/apps/cli/slack-tracker/
```

Fix any issues.

- [ ] **Step 4: Commit**

```
feat(slack-tracker): finalize with polish and edge case handling
```
