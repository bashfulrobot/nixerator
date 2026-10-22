#!/usr/bin/env bash
# notes: find and open notes. Portable: Linux and macOS, bash 3.2+.
#
#   notes                 fuzzy-pick a note by title or path (fzf)
#   notes -s [QUERY]      full-text search while typing (zk --match)
#   notes -t TAG          pick among notes with a tag
#   notes -l              launcher mode: fuzzel (Linux) or choose (macOS) menu,
#                         then open the note in the GUI viewer. For keybinds.
#
# Keys in fzf:  enter view (markless)   ctrl-o GUI viewer   ctrl-e $EDITOR
#
# Env: NOTES_DIR (default ~/Notes), NOTES_OPEN (path to notes-open).
set -euo pipefail

NOTES_DIR="${NOTES_DIR:-$HOME/Notes}"
NOTES_OPEN="${NOTES_OPEN:-notes-open}"
export ZK_NOTEBOOK_DIR="$NOTES_DIR"

[ -d "$NOTES_DIR/.zk" ] || {
  echo "notes: no notebook at $NOTES_DIR (run notes-init)" >&2
  exit 1
}
cd "$NOTES_DIR"

have() { command -v "$1" >/dev/null 2>&1; }

mode=pick
query=""
tag=""
case "${1:-}" in
-s)
  mode=search
  query="${2:-}"
  ;;
-t)
  mode=pick
  tag="${2:?usage: notes -t TAG}"
  ;;
-l) mode=launcher ;;
-h | --help)
  sed -n '2,13p' "$0"
  exit 0
  ;;
esac

# path<TAB>title, notebook-relative, newest first.
list_notes() {
  if [ -n "$tag" ]; then
    zk list --quiet --sort modified- --tag "$tag" --format '{{path}}\t{{title}}'
  else
    zk list --quiet --sort modified- --format '{{path}}\t{{title}}'
  fi
}

if [ "$mode" = launcher ]; then
  # Menu line: "title  (path)". The path is recovered from the trailing parens.
  if have fuzzel; then
    menu=(fuzzel --dmenu --prompt "notes> ")
  elif have choose; then
    menu=(choose)
  else
    menu=(fzf)
  fi
  pick=$(list_notes | awk -F'\t' '{ printf "%s  (%s)\n", $2, $1 }' | "${menu[@]}") || exit 0
  [ -n "$pick" ] || exit 0
  rel=$(printf '%s' "$pick" | sed -e 's/.*(\(.*\))$/\1/')
  exec "$NOTES_OPEN" --gui "$NOTES_DIR/$rel"
fi

have fzf || {
  echo "notes: fzf not found" >&2
  exit 1
}

preview='bat -p --color always --line-range :80 {1} 2>/dev/null || head -n 80 {1}'
# shellcheck disable=SC2054 # the commas belong to fzf option values
common=(
  --delimiter '\t'
  --with-nth 2,1
  --ansi
  --preview "$preview"
  --preview-window 'right,55%,wrap'
  --expect 'ctrl-o,ctrl-e'
  --header 'enter view  ctrl-o GUI  ctrl-e edit'
)

if [ "$mode" = search ]; then
  out=$(
    : | fzf "${common[@]}" --disabled --query "$query" \
      --bind "start:reload:zk list --quiet --sort modified- --format '{{path}}\t{{title}}' --match {q} || true" \
      --bind "change:reload:zk list --quiet --sort modified- --format '{{path}}\t{{title}}' --match {q} || true"
  ) || exit 0
else
  out=$(list_notes | fzf "${common[@]}" --query "$query") || exit 0
fi

key=$(printf '%s\n' "$out" | sed -n '1p')
line=$(printf '%s\n' "$out" | sed -n '2p')
[ -n "$line" ] || exit 0
file="$NOTES_DIR/$(printf '%s' "$line" | cut -f1)"

case "$key" in
ctrl-o) exec "$NOTES_OPEN" --gui "$file" ;;
ctrl-e) exec "$NOTES_OPEN" --edit "$file" ;;
*) exec "$NOTES_OPEN" "$file" ;;
esac
