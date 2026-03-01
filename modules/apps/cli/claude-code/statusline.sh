#!/usr/bin/env bash
# Claude Code status line -- two-line display for Kitty (OSC 8 supported)
# Receives session JSON on stdin; jq is guaranteed in PATH via runtimeInputs.

input=$(cat)

# Unicode block chars via printf (raw UTF-8 bytes -- no literal non-ASCII in source)
BLOCK=$(printf '\xe2\x96\x88')  # U+2588 FULL BLOCK
LIGHT=$(printf '\xe2\x96\x91')  # U+2591 LIGHT SHADE

# --- Model ---
model=$(echo "$input" | jq -r '.model // "unknown"' 2>/dev/null)
case "$model" in
  *opus*)   model_short="Opus" ;;
  *sonnet*) model_short="Sonnet" ;;
  *haiku*)  model_short="Haiku" ;;
  *)        model_short="$model" ;;
esac

# --- Token usage ---
used=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0' 2>/dev/null)
total=$(echo "$input" | jq -r '.context_window_size // 200000' 2>/dev/null)
pct_raw=$(echo "$input" | jq -r '.context_window.used_percentage // 0' 2>/dev/null)
pct=$(echo "$pct_raw" | awk '{printf "%.0f", $1}')
used="${used:-0}"
total="${total:-200000}"
pct="${pct:-0}"

used_k=$(awk "BEGIN {printf \"%.0f\", ${used} / 1000}")
total_k=$(awk "BEGIN {printf \"%.0f\", ${total} / 1000}")

# --- Bar (10 blocks) ---
filled=$(awk "BEGIN {n=int(${pct}/10); if(n>10)n=10; if(n<0)n=0; print n}")
filled="${filled:-0}"
empty=$(( 10 - filled ))

bar_filled=""
for (( i=0; i<filled; i++ )); do bar_filled="${bar_filled}${BLOCK}"; done
bar_empty=""
for (( i=0; i<empty; i++ )); do bar_empty="${bar_empty}${LIGHT}"; done

# Bar color based on percentage (if/elif avoids bare arithmetic with set -e)
if   (( pct >= 90 )); then bar_color=$'\033[31m'
elif (( pct >= 70 )); then bar_color=$'\033[33m'
else                       bar_color=$'\033[32m'
fi
reset=$'\033[0m'

# --- Duration ---
ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0' 2>/dev/null | awk '{printf "%.0f", $1}')
ms="${ms:-0}"
secs=$(( ms / 1000 ))
mins=$(( secs / 60 ))
secs=$(( secs % 60 ))
if (( mins > 0 )); then
  duration="${mins}m ${secs}s"
else
  duration="${secs}s"
fi

# --- Git info (cached 5s) ---
cache_file="/tmp/claude-statusline-git-cache"
now=$(date +%s)
git_line=""

if [[ -f "$cache_file" ]]; then
  cache_time=$(awk 'NR==1{print $1}' "$cache_file" 2>/dev/null || echo 0)
  cache_time="${cache_time:-0}"
  age=$(( now - cache_time ))
  if (( age < 5 )); then
    git_line=$(awk 'NR==2{print}' "$cache_file" 2>/dev/null) || git_line=""
  fi
fi

if [[ -z "$git_line" ]]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
    staged=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    modified=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    staged="${staged:-0}"
    modified="${modified:-0}"

    counts=""
    if (( staged > 0 ));   then counts=" +${staged}"; fi
    if (( modified > 0 )); then counts="${counts} ~${modified}"; fi

    # Ahead/behind upstream
    upstream=$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null)
    sync_info=""
    if [[ -n "$upstream" ]]; then
      ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
      behind=$(git rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)
      (( ahead > 0 )) && sync_info=" ↑${ahead}"
      (( behind > 0 )) && sync_info="${sync_info} ↓${behind}"
    fi

    # Stash count
    stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
    stash_info=""
    (( stash_count > 0 )) && stash_info=" ≡${stash_count}"

    # Worktree indicator (only in linked worktrees, not main)
    git_dir=$(git rev-parse --git-dir 2>/dev/null)
    common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
    wt_info=""
    if [[ -n "$git_dir" && -n "$common_dir" && "$git_dir" != "$common_dir" ]]; then
      wt_name=$(basename "$git_dir")
      wt_info=" [wt:${wt_name}]"
    fi

    counts="${counts}${sync_info}${stash_info}${wt_info}"

    # Try to build clickable OSC 8 URL (SSH -> HTTPS)
    remote_url=$(git remote get-url origin 2>/dev/null || true)
    https_url=""
    if [[ -n "$remote_url" ]]; then
      if [[ "$remote_url" =~ ^git@([^:]+):(.+)\.git$ ]]; then
        https_url="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
      elif [[ "$remote_url" =~ ^https?:// ]]; then
        https_url="${remote_url%.git}"
      fi
    fi

    if [[ -n "$https_url" ]]; then
      git_line=$'\e]8;;'"${https_url}"$'\e\\\e[36m'"${branch}"$'\e[0m\e]8;;\e\\'"${counts}"
    else
      git_line="${branch}${counts}"
    fi

    printf '%s\n%s\n' "$now" "$git_line" > "$cache_file"
  fi
fi

# --- Line 1 ---
cwd_name=$(basename "$PWD")
if [[ -n "$git_line" ]]; then
  printf '[%s] %s | %s\n' "$model_short" "$cwd_name" "$git_line"
else
  printf '[%s] %s\n' "$model_short" "$cwd_name"
fi

# --- Line 2 ---
printf '%s[%s%s]%s %s%% | %sk/%sk tokens | %s\n' \
  "$bar_color" "$bar_filled" "$bar_empty" "$reset" \
  "$pct" "$used_k" "$total_k" "$duration"
