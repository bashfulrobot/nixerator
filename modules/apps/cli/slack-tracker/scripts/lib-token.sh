# lib-token.sh — credential management
# Sourced (inlined) by writeShellApplication, not executed directly

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

  url="$(gum input --placeholder "Workspace URL (e.g. https://myteam.slack.com)" --width 60)"

  if ! validate_and_save_tokens "$workspace" "$xoxc" "$xoxd" "$url"; then
    gum log --level error "Validation failed. Try again." >&2
    if gum confirm "Retry manual entry?"; then
      refresh_manual "$workspace"
    fi
    return 1
  fi
}

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

  # CDP WebSocket in pure bash is fragile — use page-source scraping with existing cookie instead.
  # This means CDP auto-extract only works for token refresh (existing xoxd required), not fresh setup.
  local existing_xoxd=""
  if [[ -f "$CREDENTIALS_FILE" ]]; then
    existing_xoxd="$(jq -r --arg ws "$workspace" '.workspaces[$ws].xoxd // ""' "$CREDENTIALS_FILE" 2>/dev/null)"
  fi

  if [[ -z "$existing_xoxd" ]]; then
    [[ "$VERBOSE" == "true" ]] && gum log --level debug "CDP: no existing xoxd cookie on file, cannot auto-extract (need manual setup first)" >&2
    return 1
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
