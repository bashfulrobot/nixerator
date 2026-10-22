#!/usr/bin/env bash
# notes-new: create a note in a chosen folder using zk templates.
# Portable: Linux and macOS, bash 3.2+.
#
#   notes-new [TITLE...]      pick a folder with fzf, create the note, open it
#   notes-new -d DIR TITLE    skip the picker (DIR relative to the notes root)
#
# Env: NOTES_DIR (default ~/Notes), NOTES_OPEN (path to notes-open).
set -euo pipefail

NOTES_DIR="${NOTES_DIR:-$HOME/Notes}"
NOTES_OPEN="${NOTES_OPEN:-notes-open}"
export ZK_NOTEBOOK_DIR="$NOTES_DIR"

[ -d "$NOTES_DIR/.zk" ] || {
  echo "notes-new: no notebook at $NOTES_DIR (run notes-init)" >&2
  exit 1
}
cd "$NOTES_DIR"

dir=""
case "${1:-}" in
-d)
  dir="${2:?usage: notes-new -d DIR TITLE}"
  shift 2
  ;;
esac
title="$*"

if [ -z "$dir" ]; then
  command -v fzf >/dev/null 2>&1 || {
    echo "notes-new: fzf not found, use -d DIR" >&2
    exit 1
  }
  # Every folder except media/ folders, hidden dirs and the notes root.
  dir=$(find . -type d ! -name media ! -path './.*' ! -path './media' ! -path . |
    sed 's|^\./||' | sort | fzf --prompt 'folder> ') || exit 0
fi

mkdir -p "$dir/media"

if [ -z "$title" ]; then
  printf 'title: '
  read -r title
fi

file=$(zk new --no-input --print-path --title "$title" "$dir")

exec "$NOTES_OPEN" --edit "$file"
