#!/usr/bin/env bash
#
# Editor wrapper that polishes what you wrote. Claude Code's Ctrl+G (or
# Ctrl+X Ctrl+E) opens the prompt in $VISUAL/$EDITOR on a temp file and reads the
# file back on exit. A terminal editor has no compositor-level selection to
# grab, so the SUPER+SHIFT+R keybind cannot reach it. This works on the file
# instead:
#
#   1. open the file in the real editor ($POLISH_EDITOR) and wait for you to quit
#   2. polish the saved text through text-polish-core.sh
#   3. write the polished text into the file
#
# The polished text lands in the prompt box for a last look before Enter, so
# there is no confirmation step. Every failure (no rules, claude missing, safety
# filter) leaves the file as you saved it and exits 0, so a polish problem can
# never cost you the prompt.
#
# Usage: polish-editor <file>
#
# Environment:
#   POLISH_EDITOR     the real editor command, word-split (default: the host's
#                     preferred editor, substituted by Nix)
#   PE_TTY_OUT        where to print status (default: /dev/tty; tests override)
#
# Wired to Claude Code only, so other tools keep your normal editor: the
# `claude` fish function (claude-code/cfg/fish.nix) sets VISUAL and EDITOR to
# this script for that one process.
set -uo pipefail

# Tool paths are substituted by Nix; the environment overrides them for tests.
DEFAULT_EDITOR="${TEXT_POLISH_DEFAULT_EDITOR:-@default_editor@}"

# TEXT_POLISH_CORE lets the test harness source the unsubstituted file.
# shellcheck source=text-polish-core.sh
. "${TEXT_POLISH_CORE:-@core@}"

file="${1:?usage: polish-editor <file>}"
tty_out="${PE_TTY_OUT:-/dev/tty}"

# Resolve the real editor, refusing to call ourselves. The word-split is on
# purpose: POLISH_EDITOR may carry flags ("code --wait").
editor="${POLISH_EDITOR:-$DEFAULT_EDITOR}"
case "$editor" in
  polish-editor | */polish-editor | */polish-editor.sh) editor="$DEFAULT_EDITOR" ;;
esac

say() { printf '%s\n' "$*" >>"$tty_out" 2>/dev/null || printf '%s\n' "$*" >&2; }

# shellcheck disable=SC2086 # word-splitting the command is the point
$editor "$file" || exit $?

# Nothing worth polishing.
[ -s "$file" ] || exit 0
text=$(cat "$file")
case "$text" in
  *[![:space:]]*) ;;
  *) exit 0 ;;
esac

if ! polish_preflight; then
  say "polish skipped: $PT_ERR"
  exit 0
fi
if ! polish_check "$text"; then
  say "polish skipped: $PT_ERR"
  exit 0
fi

say "Polishing ${#text} characters..."
if ! polish_run "$text"; then
  say "polish skipped: $PT_ERR"
  exit 0
fi

printf '%s\n' "$PT_OUT" >"$file"
say "Polished: ${#text} -> ${#PT_OUT} characters."
exit 0
