# lib-ui.sh — gum TUI interactions
# Sourced (inlined) by writeShellApplication, not executed directly

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
    "1 week") echo "1w" ;;
    "2 weeks") echo "2w" ;;
    "3 weeks") echo "3w" ;;
    "1 month") echo "1m" ;;
    "2 months") echo "2m" ;;
    "3 months") echo "3m" ;;
    "Custom")
      gum input --placeholder "e.g. 5d, 4w, 6m" --width 20
      ;;
    *) echo "2w" ;;
  esac
}

# apply_tags <file> <tags_json>
# Modifies file in-place
apply_tags() {
  local file="$1" tags_json="$2"
  if [[ "$tags_json" == "{}" || "$tags_json" == "null" ]]; then
    return
  fi

  jq --argjson tags "$tags_json" '
    [.[] | . as $msg |
      .tags = ([
        $tags | to_entries[] |
        select(.value | any(. as $kw | $msg.text | ascii_downcase | contains($kw | ascii_downcase)))
      ] | map(.key))
    ]' "$file" >"${file}.tmp" && mv "${file}.tmp" "$file"
}

# apply_highlights <file> <highlights_json>
# Modifies file in-place
apply_highlights() {
  local file="$1" highlights_json="$2"
  if [[ "$highlights_json" == "[]" || "$highlights_json" == "null" ]]; then
    return
  fi

  jq --argjson hl "$highlights_json" '
    [.[] | . as $msg |
      .highlights = ([
        $hl[] | select(. as $kw | $msg.text | ascii_downcase | contains($kw | ascii_downcase))
      ])
    ]' "$file" >"${file}.tmp" && mv "${file}.tmp" "$file"
}

display_results_interactive() {
  local file="$1"

  while IFS= read -r msg; do
    local channel date msg_type text tags_str highlights

    channel="$(printf '%s' "$msg" | jq -r '.channel')"
    date="$(printf '%s' "$msg" | jq -r '.date')"
    msg_type="$(printf '%s' "$msg" | jq -r '.type')"
    text="$(printf '%s' "$msg" | jq -r '.text' | head -c 120)"

    # Build tag badges
    tags_str="$(printf '%s' "$msg" | jq -r '.tags | map("[\(.)]") | join(" ")')"

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
    done <<<"$highlights"

    # Format: channel  date  [tags]
    local header
    header="$(gum style --bold "${channel}")  ${date}  ${tags_str}"
    printf '%s\n' "$header"
    printf '  %s\n' "$display_text"
    printf '  %s\n\n' "$type_label"
  done < <(jq -c '.[]' "$file")
}

display_results_list() {
  local file="$1"
  # Tab-separated: date, channel, type, tags, permalink, preview (with **highlights**)
  jq -r '.[] |
    (.highlights // []) as $hl |
    (.text | gsub("\n"; " ") | .[0:100]) as $preview |
    (reduce $hl[] as $word ($preview; gsub("(?i)\($word)"; "**\($word)**"))) as $highlighted_preview |
    [.date, .channel, .type,
     (.tags | join(",")),
     .permalink,
     $highlighted_preview] | @tsv' "$file"
}

display_results_json() {
  local file="$1"
  jq '.' "$file"
}

filter_by_tag_interactive() {
  local file="$1"
  local unique_tags
  unique_tags="$(jq -r '[.[].tags[]] | unique | .[]' "$file")"

  if [[ -z "$unique_tags" ]]; then
    return
  fi

  local selected_tag
  selected_tag="$(printf '%s\n%s' "All" "$unique_tags" | gum filter --header "Filter by tag (or All):" --placeholder "type to search...")"

  if [[ "$selected_tag" == "All" || -z "$selected_tag" ]]; then
    return
  fi

  jq --arg tag "$selected_tag" '[.[] | select(.tags | index($tag))]' "$file" >"${file}.tmp" && mv "${file}.tmp" "$file"
}

select_messages_to_open() {
  local file="$1"
  # Include index in display for reliable mapping, format: "[idx] date  channel  preview"
  local options
  options="$(jq -r 'to_entries[] |
    "[\(.key)] \(.value.date)  \(.value.channel)  \(.value.text | gsub("\n"; " ") | .[0:70])"' "$file")"

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
    jq -r ".[$idx].permalink" "$file"
  done <<<"$selected"
}

walk_threads() {
  local file="$1"
  local total
  total="$(jq 'length' "$file")"
  local i=0

  while IFS= read -r entry; do
    ((i++)) || true
    local channel date text permalink
    channel="$(printf '%s' "$entry" | jq -r '.channel')"
    date="$(printf '%s' "$entry" | jq -r '.date')"
    text="$(printf '%s' "$entry" | jq -r '.text')"
    permalink="$(printf '%s' "$entry" | jq -r '.permalink')"

    # Truncate text for display
    local preview
    preview="$(printf '%s' "$text" | head -c 120)"
    [[ ${#text} -gt 120 ]] && preview="${preview}..."

    printf '\n'
    gum style --foreground 33 --bold "[${i}/${total}] ${channel} — ${date}"
    gum style --foreground 240 "$preview"

    google-chrome "$permalink" &>/dev/null &
    disown
    sleep 0.5

    if [[ "$i" -lt "$total" ]]; then
      gum confirm "Next thread?" || break
    else
      gum style --foreground 240 "Done."
    fi
  done < <(jq -c '.[]' "$file")
}
