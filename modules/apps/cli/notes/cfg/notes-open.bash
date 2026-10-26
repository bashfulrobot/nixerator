#!/usr/bin/env bash
# notes-open: open a markdown file in a viewer.
# Portable: Linux and macOS.
#
#   notes-open FILE            terminal viewer (markless, falls back to $PAGER)
#   notes-open --gui FILE      GUI viewer (Typora, else Zed, else the OS default)
#   notes-open --edit FILE     $EDITOR
#
# Env: NOTES_GUI overrides GUI detection with an explicit command.
set -euo pipefail

mode="tty"
case "${1:-}" in
--gui | --edit)
  mode="${1#--}"
  shift
  ;;
esac
file="${1:?usage: notes-open [--gui|--edit] FILE}"

have() { command -v "$1" >/dev/null 2>&1; }

open_gui() {
  if [ -n "${NOTES_GUI:-}" ]; then
    # shellcheck disable=SC2086 # NOTES_GUI is a command plus optional flags
    nohup $NOTES_GUI "$file" >/dev/null 2>&1 &
  elif have typora; then
    nohup typora "$file" >/dev/null 2>&1 &
  elif [ "$(uname -s)" = Darwin ] && [ -d /Applications/Typora.app ]; then
    open -a Typora "$file"
  elif have zeditor; then
    nohup zeditor "$file" >/dev/null 2>&1 &
  elif have zed; then
    nohup zed "$file" >/dev/null 2>&1 &
  elif have xdg-open; then
    nohup xdg-open "$file" >/dev/null 2>&1 &
  else
    open "$file"
  fi
}

case "$mode" in
gui) open_gui ;;
edit) exec "${EDITOR:-vi}" "$file" ;;
*)
  if have markless; then
    exec markless "$file"
  else
    exec "${PAGER:-less}" "$file"
  fi
  ;;
esac
