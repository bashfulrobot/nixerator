# PreCompact recovery checkpoint.
#
# Fires on PreCompact (before Claude Code compacts the context). Compaction is
# lossy -- in-flight working state can be summarized away. This writes a
# recovery snapshot so the session can be reconstructed by hand, and drops a
# per-session sentinel that post-compact-reinject.sh consumes on the next prompt
# to re-surface the hard rules exactly once.
#
# Wired into settings.json PreCompact via cfg/activation.nix (Nix-owned, stripped
# from capture in cfg/fish.nix). jq/git/coreutils/findutils on PATH via runtimeInputs.

input="$(cat)"
sid="$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null || true)"
[[ -n "$sid" ]] || exit 0
cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null || true)"
[[ -n "$cwd" ]] || cwd="$PWD"
trigger="$(jq -r '.trigger // "auto"' <<<"$input" 2>/dev/null || echo auto)"

config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
recovery_dir="$config_dir/recovery"
mkdir -p "$recovery_dir"

snapshot="$recovery_dir/$sid.md"
{
  echo "# Recovery snapshot"
  echo
  echo "- Captured: $(date -u +%Y-%m-%dT%H:%M:%SZ) (PreCompact, trigger=$trigger)"
  echo "- Session: $sid"
  echo "- cwd: $cwd"
  echo

  if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "## Git"
    echo
    echo "- Branch: $(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
    echo
    echo "### Working tree (git status --porcelain)"
    echo
    echo '```'
    git -C "$cwd" status --porcelain 2>/dev/null | head -100 || true
    echo '```'
    echo
    echo "### Recent commits"
    echo
    echo '```'
    git -C "$cwd" log --oneline -5 2>/dev/null || true
    echo '```'
    echo
  fi

  intent_log="$config_dir/intent-logs/$sid.jsonl"
  if [[ -f "$intent_log" ]]; then
    echo "## Recent prompts (intent log)"
    echo
    tail -n 10 "$intent_log" |
      jq -r '"- [" + (.timestamp // "?") + "] " + ((.prompt // "") | gsub("\n"; " ") | .[0:200])' 2>/dev/null || true
    echo
  fi
} >"$snapshot"

# Sentinel consumed once by post-compact-reinject.sh on the next UserPromptSubmit.
touch "$recovery_dir/$sid.compacted"

# Prune snapshots + sentinels older than 15 days (matches the intent-log cleanup
# cadence in the SessionStart hook).
find "$recovery_dir" -maxdepth 1 -type f \( -name '*.md' -o -name '*.compacted' \) -mtime +15 -delete 2>/dev/null || true

exit 0
