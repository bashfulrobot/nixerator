# lib-api.sh — Slack API calls
# Sourced (inlined) by writeShellApplication, not executed directly

SLACK_XOXC="${SLACK_XOXC:-}"
SLACK_XOXD="${SLACK_XOXD:-}"
MY_USER_ID=""
MY_USERNAME=""

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
      retry_after="$(grep -m1 -oi 'Retry-After: *[0-9]*' "$header_file" | grep -o '[0-9]*')"
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
  MY_USERNAME="$(printf '%s' "$response" | jq -r '.user')"
}

# search_my_messages <after_date> <output_file>
# Writes JSON array of messages to output_file
search_my_messages() {
  local after_date="$1" out_file="$2"
  local query="from:${MY_USERNAME} after:${after_date}"
  local page=1
  local total=0

  printf '[]' >"$out_file"

  while true; do
    local response
    response="$(slack_api "search.messages?query=$(printf '%s' "$query" | jq -sRr @uri)&count=100&page=${page}&sort=timestamp&sort_dir=desc")" || return 1

    if [[ $page -eq 1 ]]; then
      total="$(printf '%s' "$response" | jq '.messages.total // 0')"
      if [[ "$total" -eq 0 ]]; then
        return 0
      fi
    fi

    # Append matches to file via jq slurp
    local tmp_page
    tmp_page="$(mktemp)"
    printf '%s' "$response" | jq '.messages.matches // []' >"$tmp_page"
    jq -s '.[0] + .[1]' "$out_file" "$tmp_page" >"${out_file}.tmp" && mv "${out_file}.tmp" "$out_file"
    rm -f "$tmp_page"

    local page_count
    page_count="$(printf '%s' "$response" | jq '.messages.paging.pages // 1')"
    if [[ $page -ge $page_count ]]; then
      break
    fi
    ((page++))
  done
}

get_thread_info() {
  local channel_id="$1" thread_ts="$2"
  local response
  # Fetch all replies — conversations.replies is a GET endpoint
  response="$(slack_api "conversations.replies?channel=${channel_id}&ts=${thread_ts}")" || return 1

  # messages[0] is the parent; length > 1 means replies exist
  local reply_count last_user
  reply_count="$(printf '%s' "$response" | jq '.messages | length')"
  last_user="$(printf '%s' "$response" | jq -r '.messages | last | .user // ""')"
  printf '%s %s' "$reply_count" "$last_user"
}

# Thread classification cache — avoids re-checking messages across runs.
# Cache format: one "channel_id:ts=result" per line
# result is "answered", "unanswered", or "no_thread"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/slack-tracker"
CACHE_FILE="${CACHE_DIR}/thread-cache"

_cache_lookup() {
  local key="$1"
  if [[ -f "$CACHE_FILE" ]]; then
    grep -m1 "^${key}=" "$CACHE_FILE" 2>/dev/null | cut -d= -f2 || true
  fi
}

_cache_store() {
  local key="$1" value="$2"
  mkdir -p "$CACHE_DIR"
  printf '%s=%s\n' "$key" "$value" >>"$CACHE_FILE"
}

# classify_messages <input_file> <output_file>
# Reads messages JSON from input_file, writes classified results to output_file
classify_messages() {
  local in_file="$1" out_file="$2"
  local total
  total="$(jq 'length' "$in_file")"

  printf '[]' >"$out_file"
  local count=0 cached=0 api_calls=0

  while IFS= read -r msg; do
    ((count++)) || true
    printf '\r  Checking message %d/%d (cached: %d)...' "$count" "$total" "$cached" >&2

    local channel channel_id text ts permalink
    channel="$(printf '%s' "$msg" | jq -r '.channel.name // "unknown"')"
    channel_id="$(printf '%s' "$msg" | jq -r '.channel.id // ""')"
    text="$(printf '%s' "$msg" | jq -r '.text // ""')"
    ts="$(printf '%s' "$msg" | jq -r '.ts // ""')"
    permalink="$(printf '%s' "$msg" | jq -r '.permalink // ""')"

    local cache_key="${channel_id}:${ts}"
    local msg_type=""

    # Check cache first
    local cached_result
    cached_result="$(_cache_lookup "$cache_key")"
    if [[ -n "$cached_result" ]]; then
      ((cached++)) || true
      if [[ "$cached_result" == "unanswered" ]]; then
        msg_type="last_commenter"
      fi
    else
      # Throttle to stay under Slack's Tier 3 rate limit (~50 req/min)
      if [[ "$api_calls" -gt 0 ]]; then
        sleep 1.2
      fi
      ((api_calls++)) || true

      # Fetch thread info from conversations.replies (search results don't
      # include reliable reply_count). Skip unthreaded messages — they may
      # have been answered informally in-channel.
      local thread_info
      if thread_info="$(get_thread_info "$channel_id" "$ts")"; then
        local reply_count last_user
        reply_count="${thread_info%% *}"
        last_user="${thread_info#* }"
        # reply_count > 1 means replies exist (messages[0] is the parent)
        if [[ "$reply_count" -gt 1 && "$last_user" == "$MY_USER_ID" ]]; then
          msg_type="last_commenter"
          _cache_store "$cache_key" "unanswered"
        elif [[ "$reply_count" -gt 1 ]]; then
          _cache_store "$cache_key" "answered"
        else
          _cache_store "$cache_key" "no_thread"
        fi
      fi
    fi

    if [[ -n "$msg_type" ]]; then
      local date_str
      date_str="$(date -d "@${ts%.*}" +%Y-%m-%d 2>/dev/null || echo "unknown")"
      local tmp_entry
      tmp_entry="$(mktemp)"
      jq -n \
        --arg channel "#${channel}" \
        --arg channel_id "$channel_id" \
        --arg text "$text" \
        --arg date "$date_str" \
        --arg permalink "$permalink" \
        --arg type "$msg_type" \
        '[{channel: $channel, channel_id: $channel_id, text: $text, date: $date, permalink: $permalink, type: $type, tags: [], highlights: []}]' >"$tmp_entry"
      jq -s '.[0] + .[1]' "$out_file" "$tmp_entry" >"${out_file}.tmp" && mv "${out_file}.tmp" "$out_file"
      rm -f "$tmp_entry"
    fi
  done < <(jq -c '.[]' "$in_file")

  printf '\r%*s\r' 40 '' >&2 # Clear progress line
}
