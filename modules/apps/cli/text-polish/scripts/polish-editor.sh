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
#   3. show a word diff, then ask [Y]es / [n]o / [e]dit
#
# Yes writes the polished text into the file, so it lands in the prompt box for a
# last look before Enter. No leaves your text alone. Edit writes the polished
# text and reopens the editor on it. Every failure (no rules, claude missing,
# safety filter, no terminal to ask on) leaves the file as you saved it and exits
# 0, so a polish problem can never cost you the prompt.
#
# Usage: polish-editor <file>
#
# Environment:
#   POLISH_EDITOR     the real editor command, word-split (default: the host's
#                     preferred editor, substituted by Nix)
#   PE_TTY_IN/OUT     where to ask and print (default: /dev/tty; tests override)
#
# Wired to Claude Code only, so other tools keep your normal editor: the fish
# function `claude` (see default.nix) sets VISUAL and EDITOR to this script for
# that one process.
set -uo pipefail

# Tool paths are substituted by Nix; the environment overrides them for tests.
GIT="${TEXT_POLISH_GIT:-@git@}"
DIFF="${TEXT_POLISH_DIFF:-@diff@}"
DEFAULT_EDITOR="${TEXT_POLISH_DEFAULT_EDITOR:-@default_editor@}"

# TEXT_POLISH_CORE lets the test harness source the unsubstituted file.
# shellcheck source=text-polish-core.sh
. "${TEXT_POLISH_CORE:-@core@}"

file="${1:?usage: polish-editor <file>}"
tty_in="${PE_TTY_IN:-/dev/tty}"
tty_out="${PE_TTY_OUT:-/dev/tty}"

# Resolve the real editor, refusing to call ourselves. The word-split is on
# purpose: POLISH_EDITOR may carry flags ("code --wait").
editor="${POLISH_EDITOR:-$DEFAULT_EDITOR}"
case "$editor" in
  polish-editor | */polish-editor | */polish-editor.sh) editor="$DEFAULT_EDITOR" ;;
esac

say() { printf '%s\n' "$*" >>"$tty_out" 2>/dev/null || printf '%s\n' "$*" >&2; }

run_editor() {
  # shellcheck disable=SC2086 # word-splitting the command is the point
  $editor "$file"
}

# Print a word diff of the original against the polished text. The first five
# lines of `git diff --no-index` output are headers.
show_diff() {
  local before="$1" after="$2"
  if [ -x "$GIT" ] || command -v "$GIT" >/dev/null 2>&1; then
    "$GIT" diff --no-index --word-diff=color -- "$before" "$after" 2>/dev/null |
      sed -n '6,$p' >>"$tty_out" 2>/dev/null
  else
    "$DIFF" -u "$before" "$after" >>"$tty_out" 2>/dev/null
  fi
}

run_editor || exit $?

# Nothing worth polishing.
[ -s "$file" ] || exit 0
text=$(cat "$file")
case "$text" in
  *[![:space:]]*) ;;
  *) exit 0 ;;
esac

# Without a terminal to ask on there is no way to confirm, so leave it alone.
if ! : <"$tty_in" 2>/dev/null; then
  exit 0
fi

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

# Identical output needs no confirmation.
if [ "$PT_OUT" = "$text" ]; then
  say "Already tight, nothing changed."
  exit 0
fi

workdir=$(mktemp -d) || exit 0
trap 'rm -rf "$workdir"' EXIT
printf '%s\n' "$text" >"$workdir/before.txt"
printf '%s\n' "$PT_OUT" >"$workdir/after.txt"

show_diff "$workdir/before.txt" "$workdir/after.txt"
printf 'Apply polish? [Y]es / [n]o / [e]dit: ' >>"$tty_out" 2>/dev/null

answer=""
read -r -n 1 answer <"$tty_in" || answer="n"
say ""

case "$answer" in
  "" | y | Y)
    printf '%s\n' "$PT_OUT" >"$file"
    ;;
  e | E)
    printf '%s\n' "$PT_OUT" >"$file"
    run_editor || exit $?
    ;;
  *) ;;
esac
exit 0
