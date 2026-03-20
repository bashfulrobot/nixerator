# lib-api.sh — Slack API calls
# Sourced (inlined) by writeShellApplication, not executed directly

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
