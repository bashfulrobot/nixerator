# Post-compaction reinjection.
#
# Runs on UserPromptSubmit. precompact-checkpoint.sh drops a per-session
# `.compacted` sentinel whenever a compaction happens; on the very next prompt
# this re-surfaces the hard rules most likely to have been summarized away, then
# clears the sentinel so it fires exactly once per compaction. stdout from a
# UserPromptSubmit hook is injected into the model context -- which is the whole
# point: the rules land back in context right after the lossy compaction.
#
# Wired into settings.json UserPromptSubmit via cfg/activation.nix (Nix-owned,
# stripped from capture in cfg/fish.nix). jq/coreutils on PATH via runtimeInputs.

input="$(cat)"
sid="$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null || true)"
[[ -n "$sid" ]] || exit 0

config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
recovery_dir="$config_dir/recovery"
sentinel="$recovery_dir/$sid.compacted"
[[ -f "$sentinel" ]] || exit 0

# Fire once: clear the sentinel before printing so a failure can't loop it.
rm -f "$sentinel"

cat <<'EOF'
[context-recovery] A compaction just occurred -- re-surfacing hard rules that may have been summarized away:
- Secrets/1Password: NEVER read rendered secret values, not even a prefix or length. op:// paths, item titles, field labels, and placeholders only.
- Slack: only send via the /slack-post skill, and only when explicitly asked this turn. The Slack MCP message-writing tools are off-limits.
- Writing: run any prose I will read or send through the humanizer skill before presenting it.
- Git: no Co-Authored-By / AI-attribution trailers; the user's git identity is the sole author.
EOF

snapshot="$recovery_dir/$sid.md"
if [[ -f "$snapshot" ]]; then
  echo "- Recovery snapshot (branch, git status, recent intents): $snapshot"
fi

exit 0
