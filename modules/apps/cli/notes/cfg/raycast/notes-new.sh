#!/bin/bash
# Raycast Script Command: create a note in a folder and open it in Typora.
# Install: same directory as notes-find.sh.
#
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title New Note
# @raycast.mode silent
#
# Optional parameters:
# @raycast.icon ➕
# @raycast.packageName Notes
# @raycast.argument1 { "type": "text", "placeholder": "Title" }
# @raycast.argument2 { "type": "text", "placeholder": "Folder, e.g. 00-inbox", "optional": true }
#
# The folder defaults to 00-inbox. It is created, with its media/, if missing.

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

dir="${2:-00-inbox}"
case "$dir" in
/* | .. | ../* | */.. | */../* | .*)
  echo "Folder must be a plain relative path"
  exit 1
  ;;
esac

file=$(cd "${NOTES_DIR:-$HOME/Notes}" && mkdir -p "$dir/media" && zk new --no-input --print-path --title "$1" "$dir") || {
  echo "Could not create the note"
  exit 1
}
exec notes-open --gui "$file"
