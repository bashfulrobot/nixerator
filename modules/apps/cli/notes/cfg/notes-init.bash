#!/usr/bin/env bash
# notes-init: create the notes hierarchy, zk config and .stignore. Idempotent.
# Portable: bash 3.2 (macOS) and 5.x, no GNU-only flags.
#
#   notes-init            create anything missing, never overwrite
#   notes-init --update   also overwrite .zk/config.toml and templates
#
# Env: NOTES_DIR (default ~/Notes), NOTES_SHARE (dir holding hierarchy.txt and
# zk/, default: the directory of this script).
set -euo pipefail

NOTES_DIR="${NOTES_DIR:-$HOME/Notes}"
NOTES_SHARE="${NOTES_SHARE:-$(cd "$(dirname "$0")" && pwd)}"
update=0
[ "${1:-}" = "--update" ] && update=1

hierarchy="$NOTES_SHARE/hierarchy.txt"
[ -f "$hierarchy" ] || {
  echo "notes-init: missing $hierarchy" >&2
  exit 1
}

mkdir -p "$NOTES_DIR"

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
  "" | \#*) continue ;;
  esac
  mkdir -p "$NOTES_DIR/$line/media"
done <"$hierarchy"

# Syncthing ignores. The root media/ is a derived symlink farm for Weave (see
# notes-weave-media) and the zk index is rebuilt per device.
ignore="$NOTES_DIR/.stignore"
if [ ! -f "$ignore" ]; then
  cat >"$ignore" <<'EOF'
.zk/notebook.db
.zk/notebook.db-*
/media
(?d).DS_Store
*.sync-conflict-*
EOF
fi

# zk notebook config and templates. Copied once, then owned by the notebook
# (Syncthing carries edits between devices).
mkdir -p "$NOTES_DIR/.zk/templates"
if [ "$update" = 1 ] || [ ! -f "$NOTES_DIR/.zk/config.toml" ]; then
  cp "$NOTES_SHARE/zk/config.toml" "$NOTES_DIR/.zk/config.toml"
fi
for t in "$NOTES_SHARE"/zk/templates/*.md; do
  dest="$NOTES_DIR/.zk/templates/$(basename "$t")"
  if [ "$update" = 1 ] || [ ! -f "$dest" ]; then
    cp "$t" "$dest"
  fi
done

echo "notes-init: ready at $NOTES_DIR"
