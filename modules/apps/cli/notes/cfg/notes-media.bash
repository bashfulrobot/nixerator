#!/usr/bin/env bash
# notes-media: put an image or file into a note's own media/ folder and print
# the markdown link. Portable: Linux (wl-paste, xclip) and macOS (pngpaste).
#
#   notes-media NOTE.md FILE   copy FILE into NOTE's media/ folder
#   notes-media NOTE.md        take the image from the clipboard
#
# The stored name is <YYYYMMDD-HHMMSS>-<name>. The prefix keeps names unique
# across all folders, which notes-weave-media needs to flatten them for Weave.
# The link is printed and, when --append is first, appended to the note.
set -euo pipefail

append=0
if [ "${1:-}" = "--append" ]; then
  append=1
  shift
fi
note="${1:?usage: notes-media [--append] NOTE.md [FILE]}"
src="${2:-}"

media="$(cd "$(dirname "$note")" && pwd)/media"
mkdir -p "$media"
stamp=$(date +%Y%m%d-%H%M%S)

# Prefix with the timestamp, and add -2, -3, ... when that name is taken, so a
# second paste in the same second never overwrites the first.
unique_name() {
  local base="$1" n=1 candidate
  candidate="$stamp-$base"
  while [ -e "$media/$candidate" ]; do
    n=$((n + 1))
    candidate="$stamp-$n-$base"
  done
  printf '%s' "$candidate"
}

if [ -n "$src" ]; then
  name=$(unique_name "$(basename "$src" | tr ' ' '-')")
  cp "$src" "$media/$name"
else
  name=$(unique_name clip.png)
  if command -v wl-paste >/dev/null 2>&1 && [ -n "${WAYLAND_DISPLAY:-}" ]; then
    wl-paste --type image/png >"$media/$name"
  elif command -v pngpaste >/dev/null 2>&1; then
    pngpaste "$media/$name"
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -t image/png -o >"$media/$name"
  else
    echo "notes-media: no clipboard image tool (wl-paste, pngpaste, xclip)" >&2
    exit 1
  fi
  [ -s "$media/$name" ] || {
    rm -f "$media/$name"
    echo "notes-media: clipboard has no image" >&2
    exit 1
  }
fi

link="![](media/$name)"
echo "$link"
if [ "$append" = 1 ]; then
  printf '\n%s\n' "$link" >>"$note"
fi
