#!/usr/bin/env bash
# notes-weave-media: rebuild <notes root>/media as a symlink farm of every
# per-folder media file. Weave serves one attachment directory at /media and
# rewrites a note's `media/x.png` to /media/x.png, so a flat view is the only
# way for it to find images that live next to each note.
#
# The root media/ is derived data: .stignore keeps it out of Syncthing, and
# the Weave host runs this before start and on a timer. Idempotent.
# Name collisions keep the first file and are reported on stderr.
set -euo pipefail

NOTES_DIR="${NOTES_DIR:-$HOME/Notes}"
farm="$NOTES_DIR/media"

mkdir -p "$farm"
# Drop links whose target vanished, then add any missing.
find "$farm" -maxdepth 1 -type l ! -exec test -e {} \; -exec rm -f {} \;

cd "$NOTES_DIR"
find . -mindepth 3 -type f -path '*/media/*' ! -path './media/*' ! -path './.*' |
  while IFS= read -r rel; do
    f="$NOTES_DIR/${rel#./}"
    link="$farm/$(basename "$f")"
    if [ -L "$link" ]; then
      [ "$(readlink "$link")" = "$f" ] ||
        echo "notes-weave-media: name collision, skipping $f" >&2
    elif [ -e "$link" ]; then
      echo "notes-weave-media: $link is not a symlink, skipping $f" >&2
    else
      ln -s "$f" "$link"
    fi
  done
