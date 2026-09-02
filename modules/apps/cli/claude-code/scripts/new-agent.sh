#!/usr/bin/env bash
# claude-new-agent — pick a folder via a native GTK folder-chooser (the same
# GtkFileChooser widget family Nautilus itself is built on) and start a NAMED
# background Claude Code session there with Remote Control enabled.
#
# Linux/Hyprland counterpart to donkeykong's Raycast "New Claude Agent"
# script (raycast-scripts/claude-new-agent.sh): same `claude --bg --name X
# --remote-control X` launch the bare `claude` fish wrapper uses
# (cfg/fish.nix), reachable with no shell open yet, from any folder.
# Deliberately skips that wrapper's interactive name prompt,
# worktree-per-session isolation, and terminal attach — those need a TTY
# this keybind doesn't have; same tradeoff the macOS script documents.
set -uo pipefail

ZENITY="@zenity@"
CLAUDE="@claude@"
WL_COPY="@wl_copy@"
NOTIFY="@notify_send@"

TITLE="New Claude Agent"
NOTIFY_TAG="claude-new-agent"

notify() { "$NOTIFY" "$TITLE" "$1" --icon=utilities-terminal --hint=string:x-dunst-stack-tag:"$NOTIFY_TAG" 2>/dev/null || true; }
notify_error() { "$NOTIFY" "$TITLE" "$1" --icon=dialog-error --hint=string:x-dunst-stack-tag:"$NOTIFY_TAG" 2>/dev/null || true; }

folder="$("$ZENITY" --file-selection --directory --title="Start a new Claude agent in:" 2>/dev/null)"
rc=$?

# zenity exits 1 for Cancel / window closed — not worth a notification.
# Anything else nonzero is a real error (e.g. the dialog crashed).
if [ "$rc" -eq 1 ]; then
  exit 0
elif [ "$rc" -ne 0 ]; then
  notify_error "zenity exited with status $rc"
  exit 1
fi

folder="${folder%/}"
if [ -z "$folder" ]; then
  exit 0
fi
name="$(basename "$folder")"

out="$(cd "$folder" && "$CLAUDE" --bg --name "$name" --remote-control "$name" 2>&1)"
rc=$?

if [ "$rc" -ne 0 ]; then
  notify_error "$(printf '%s' "$out" | head -1)"
  exit 1
fi

# `claude --bg` prints a `claude attach <id>` line on success (see the fish
# wrapper this mirrors). Copy it to the clipboard so jumping into the new
# session from a terminal is a paste rather than a trip through `claude
# agents` to find the id.
attach="$(printf '%s' "$out" | grep -Eo 'claude attach [^ ]+' | head -1)"
if [ -n "$attach" ]; then
  printf '%s' "$attach" | "$WL_COPY"
  notify "$name ($folder)
Attach command copied: $attach"
else
  notify "$name ($folder)
$(printf '%s' "$out" | head -3)"
fi
