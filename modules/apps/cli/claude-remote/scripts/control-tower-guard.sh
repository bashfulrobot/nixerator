#!/usr/bin/env bash
# NOTE: set -euo pipefail and PATH are set by writeShellApplication.
# PreToolUse hook for the claude-control-tower session. Allow only
# Bash(claude-remote ...); reject every other tool call with exit 2
# so Claude Code reports the denial back to the model.

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)

if [[ "$tool" == "Bash" ]]; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
  if [[ "$cmd" =~ ^[[:space:]]*claude-remote([[:space:]]|$) ]]; then
    exit 0
  fi
  printf "[control-tower] Rejected: this session can only invoke 'claude-remote <repo> [prompt]'. Got: %s\n" "$cmd" >&2
  exit 2
fi

printf '[control-tower] Rejected: tool %s is disabled in this session. Only Bash(claude-remote ...) is permitted.\n' "${tool:-unknown}" >&2
exit 2
