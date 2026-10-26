#!/usr/bin/env bash
# One `claude_stack.py apply --write` call, replacing the settings.json jq
# merge cfg/activation.nix used to carry (the force/union half of it).
#
# claude-skills owns every settings key its manifest declares -- model,
# outputStyle, statusLine, env, permissions.{deny,ask,defaultMode,
# additionalDirectories}, hooks.PostToolUse, the UI and telemetry flags -- and
# unions permissions.allow add-only. Nix owns only the machine mechanics, which
# reach the manifest as @VAR@ values. See .claude/docs/claude-stack-apply.md
# for the ownership table and the switch-on steps.
#
# Usage: claude-stack-apply <claude-skills-root> <host> <base-vars-json> [claude-dir]
#
#   claude-skills-root  the flake input's store path (holds scripts/claude_stack.py
#                       and claude-stack/resolved/<host>.json)
#   host                which resolved host file to apply (apps.cli.claude-code.stackHost)
#   base-vars-json      Nix-generated @VAR@ values, minus XDG_RUNTIME_DIR
#   claude-dir          defaults to $HOME/.claude
#
# Two things Nix cannot do itself and this script does:
#
#   1. XDG_RUNTIME_DIR is resolved from a real `id -u` here, at activation time
#      on the real host. Nix eval can run cross-host (`just build-host`) and
#      would bake in the wrong UID -- the same reason cfg/activation.nix
#      resolved it at activation before this script existed.
#   2. The values go to apply through a FILE, never inline on the command line.
#      `--vars` accepts both; a process argument list is visible to every other
#      user through `ps`, and the declared `env` block passes through it.
#
# No value is ever printed. apply itself prints key names, dest paths and
# counts only (claude-skills docs/ai/claude-stack.md), and nothing below echoes
# the vars file or its contents.

set -euo pipefail

root="${1:?claude-stack-apply: claude-skills root required}"
host="${2:?claude-stack-apply: host required}"
base_vars="${3:?claude-stack-apply: base vars file required}"
claude_dir="${4:-$HOME/.claude}"

if [ ! -f "$root/scripts/claude_stack.py" ]; then
  echo "claude-stack-apply: no scripts/claude_stack.py under $root -- re-lock the claude-skills flake input" >&2
  exit 1
fi

if [ ! -f "$root/claude-stack/resolved/$host.json" ]; then
  echo "claude-stack-apply: no claude-stack/resolved/$host.json under $root -- resolve that host in claude-skills first" >&2
  exit 1
fi

# One-shot rollback copy, taken before the first apply this host ever runs and
# never overwritten after. It is the pre-stackApply settings.json, which is the
# only thing a rollback actually wants: restoring yesterday's apply output
# would just hand back the same manifest-owned values.
#
# `-e`, not `-f`: a leftover symlink here must not be silently written through.
# Phase 6 of the central-config plan names this file as the rollback artifact
# and home-manager does not produce it (backupFileExtension is unset), so it is
# made here.
if [ ! -e "$claude_dir/settings.json.nix-backup" ] && [ -f "$claude_dir/settings.json" ]; then
  cp -p "$claude_dir/settings.json" "$claude_dir/settings.json.nix-backup"
  echo "claude-stack-apply: kept the pre-apply settings.json as settings.json.nix-backup"
fi

# 0600 because the file carries host identity (PATH, runtime dir, store
# paths), not because any of it is secret. mktemp honours TMPDIR, which
# home-manager activation sets; the file is removed on every exit path.
vars_file="$(mktemp)"
trap 'rm -f "$vars_file"' EXIT
chmod 600 "$vars_file"
jq --arg rt "/run/user/$(id -u)" '. + { XDG_RUNTIME_DIR: $rt }' "$base_vars" >"$vars_file"

# Two attempts. apply reports SETTINGS_RACE and writes nothing when Claude
# Code rewrote settings.json during the merge (it takes no lock of its own),
# which is likely enough during a rebuild with a live session open. apply is
# idempotent, so a retry is free; a second failure is a real one and fails the
# activation rather than leaving the file half-owned.
attempt=1
while :; do
  if python3 "$root/scripts/claude_stack.py" apply --write \
    --host "$host" \
    --vars "$vars_file" \
    --claude-dir "$claude_dir"; then
    exit 0
  fi
  if [ "$attempt" -ge 2 ]; then
    echo "claude-stack-apply: apply failed twice for host $host" >&2
    exit 1
  fi
  attempt=$((attempt + 1))
  sleep 1
done
