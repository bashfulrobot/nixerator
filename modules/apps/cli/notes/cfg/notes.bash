#!/usr/bin/env bash
# notes: find and open notes. Portable: Linux and macOS, bash 3.2+.
set -euo pipefail

NOTES_DIR="${NOTES_DIR:-$HOME/Notes}"
NOTES_OPEN="${NOTES_OPEN:-notes-open}"
export ZK_NOTEBOOK_DIR="$NOTES_DIR"
self="$0"

usage() {
  cat <<'EOF'
usage:
  notes [QUERY]         fuzzy-pick a note by title or path (fzf)
  notes -s [QUERY]      full-text search while typing (zk --match)
  notes -t TAG          pick among notes with a tag
  notes -l [QUERY]      launcher: fuzzel (Linux) or choose (macOS) menu, then
                        open the note in the GUI viewer. QUERY limits the menu
                        to notes whose text matches. For keybinds and Raycast.

keys in fzf:  enter view (markless)   ctrl-o GUI viewer   ctrl-e $EDITOR
env:          NOTES_DIR (default ~/Notes), NOTES_OPEN (path to notes-open)
EOF
}

case "${1:-}" in
-h | --help)
  usage
  exit 0
  ;;
esac

[ -d "$NOTES_DIR/.zk" ] || {
  echo "notes: no notebook at $NOTES_DIR (run notes-init)" >&2
  exit 1
}
cd "$NOTES_DIR"

have() { command -v "$1" >/dev/null 2>&1; }

# title<TAB>path, notebook-relative, newest first. Optional $1 is a full-text
# query; empty means every note.
list_notes() {
  local args=(--quiet --sort modified- --format '{{title}}\t{{path}}')
  [ -n "${tag:-}" ] && args+=(--tag "$tag")
  [ -n "${1:-}" ] && args+=(--match "$1")
  zk list "${args[@]}"
}

mode=pick
query=""
tag=""
case "${1:-}" in
__list)
  # Internal: fzf reload callback for search mode.
  list_notes "${2:-}" || true
  exit 0
  ;;
-s)
  mode=search
  query="${2:-}"
  ;;
-t)
  tag="${2:?usage: notes -t TAG}"
  ;;
-l)
  mode=launcher
  query="${2:-}"
  ;;
-*)
  usage >&2
  exit 2
  ;;
*) query="$*" ;;
esac

if [ "$mode" = launcher ]; then
  # Menu line: "title  (path)". The path is recovered from the trailing parens.
  if have fuzzel; then
    menu=(fuzzel --dmenu --prompt "notes> ")
  elif have choose; then
    menu=(choose)
  else
    menu=(fzf)
  fi
  menu_lines=$(list_notes "$query" | awk -F'\t' '{ printf "%s  (%s)\n", $1, $2 }')
  [ -n "$menu_lines" ] || {
    echo "No notes match"
    exit 0
  }
  pick=$(printf '%s\n' "$menu_lines" | "${menu[@]}") || exit 0
  [ -n "$pick" ] || exit 0
  rel=$(printf '%s' "$pick" | sed -e 's/.*(\(.*\))$/\1/')
  exec "$NOTES_OPEN" --gui "$NOTES_DIR/$rel"
fi

have fzf || {
  echo "notes: fzf not found" >&2
  exit 1
}

preview='bat -p --color always --line-range :80 {2} 2>/dev/null || head -n 80 {2}'
# shellcheck disable=SC2054 # the commas belong to fzf option values
common=(
  --delimiter '\t'
  --ansi
  --preview "$preview"
  --preview-window 'right,55%,wrap'
  --expect 'ctrl-o,ctrl-e'
  --header 'enter view  ctrl-o GUI  ctrl-e edit'
)

if [ "$mode" = search ]; then
  # fzf runs reload commands through $SHELL, so keep the command to one
  # simple invocation that works in bash, zsh and fish alike.
  out=$(
    : | fzf "${common[@]}" --disabled --query "$query" \
      --bind "start:reload:bash '$self' __list {q}" \
      --bind "change:reload:bash '$self' __list {q}"
  ) || exit 0
else
  out=$(list_notes | fzf "${common[@]}" --query "$query") || exit 0
fi

key=$(printf '%s\n' "$out" | sed -n '1p')
line=$(printf '%s\n' "$out" | sed -n '2p')
[ -n "$line" ] || exit 0
file="$NOTES_DIR/$(printf '%s' "$line" | cut -f2)"

case "$key" in
ctrl-o) exec "$NOTES_OPEN" --gui "$file" ;;
ctrl-e) exec "$NOTES_OPEN" --edit "$file" ;;
*) exec "$NOTES_OPEN" "$file" ;;
esac
