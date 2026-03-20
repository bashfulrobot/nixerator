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
  # shellcheck disable=SC2034
  DEFAULT_WORKSPACE="$(jq -r '.default_workspace // ""' "$CONFIG_FILE")"
  # shellcheck disable=SC2034
  DEFAULT_PERIOD="$(jq -r '.default_period // "2w"' "$CONFIG_FILE")"
  # shellcheck disable=SC2034
  HIGHLIGHTS_JSON="$(jq -c '.highlights // []' "$CONFIG_FILE")"
  # shellcheck disable=SC2034
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
  # shellcheck disable=SC2034
  SLACK_XOXC="$xoxc"
  # shellcheck disable=SC2034
  SLACK_XOXD="$xoxd"
  # shellcheck disable=SC2034
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

WORKSPACE_OVERRIDE=""

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

main "$@"
