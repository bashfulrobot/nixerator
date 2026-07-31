#!/usr/bin/env bash
set -euo pipefail

skills_dir="$HOME/.claude/skills"
if [[ ! -d "$skills_dir" ]]; then
  echo "No skills directory found at $skills_dir" >&2
  exit 1
fi

for cmd in fzf jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd is required but not installed." >&2
    exit 1
  fi
done

mapfile -t skills < <(
  find "$skills_dir" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" \
    | while read -r name; do
        [[ -f "$skills_dir/$name/SKILL.md" ]] && printf '%s\n' "$name"
      done \
    | sort
)
if [[ ${#skills[@]} -eq 0 ]]; then
  echo "No skills with a top-level SKILL.md found in $skills_dir" >&2
  exit 1
fi

output=".claude/settings.local.json"

# Discover skills already disabled in this project's settings.local.json so the
# picker starts in sync. Unlike mcp-pick, a checked row here means "disabled"
# (off), not "included" -- skills are on by default everywhere, so the picker's
# job is marking exceptions, not building a set from nothing.
declare -A disabled=()
if [[ -f "$output" ]]; then
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    disabled["$name"]=1
  done < <(jq -r '.skillOverrides // {} | to_entries[] | select(.value == "off") | .key' "$output" 2>/dev/null || true)
fi

build_lines() {
  local name marker
  for name in "${skills[@]}"; do
    if [[ -n "${disabled[$name]:-}" ]]; then
      marker="✓"
    else
      marker=" "
    fi
    # Tab-delimited so fzf can display the marker but search only the name.
    printf '%s\t%s\n' "$marker" "$name"
  done
}

preselect_chain=""
idx=0
for name in "${skills[@]}"; do
  idx=$((idx + 1))
  if [[ -n "${disabled[$name]:-}" ]]; then
    preselect_chain+="pos(${idx})+select+"
  fi
done
preselect_chain+="pos(1)"

header_lines=(
  "Toggle: Tab (also Shift+Tab) · select all: Ctrl-A · clear all: Ctrl-D"
  "Save: Enter (merges skillOverrides into ./${output}) · Cancel: Esc"
  "✓ = will be OFF for this project · unchecked = ON (the default everywhere)"
)
if (( ${#disabled[@]} > 0 )); then
  header_lines+=("Currently off here: $(printf '%s, ' "${!disabled[@]}" | sed 's/, $//')")
fi
header="$(printf '%s\n' "${header_lines[@]}")"

selected="$(build_lines | fzf -m \
  --prompt="Skills (select = OFF)> " \
  --height=60% \
  --layout=reverse \
  --delimiter=$'\t' \
  --with-nth=1,2 \
  --nth=2 \
  --bind="ctrl-a:select-all,ctrl-d:deselect-all" \
  --bind="load:${preselect_chain}" \
  --header="$header" \
  --header-first)"
# An empty selection is valid here (it means "re-enable everything"), unlike
# mcp-pick where an empty pick has nothing useful to write -- so don't bail
# out on empty; only bail if the user hit Esc, which fzf reports as exit != 0
# and is already handled by `set -e` above via the subshell's exit status.

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if ! grep -qE '(^|/)\.claude/settings\.local\.json$' .gitignore 2>/dev/null; then
    echo "Warning: .gitignore does not include .claude/settings.local.json" >&2
  fi
fi

mkdir -p "$(dirname "$output")"
[[ -f "$output" ]] || echo '{}' > "$output"

new_names=()
while IFS=$'\t' read -r _marker name; do
  [[ -n "$name" ]] || continue
  new_names+=("$name")
done <<< "$selected"

overrides_json="$(printf '%s\n' "${new_names[@]:-}" | jq -R 'select(length > 0)' | jq -s 'map({(.): "off"}) | add // {}')"

tmp="$(mktemp)"
trap 'rm -f "${tmp:-}"' EXIT
jq --argjson ov "$overrides_json" \
  'if ($ov | length) > 0 then .skillOverrides = $ov else del(.skillOverrides) end' \
  "$output" > "$tmp"
mv "$tmp" "$output"
echo "Wrote $output ($(echo "$overrides_json" | jq 'length') skill(s) off)"
