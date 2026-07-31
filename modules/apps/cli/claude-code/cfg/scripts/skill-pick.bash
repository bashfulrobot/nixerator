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

user_settings="$HOME/.claude/settings.json"
output=".claude/settings.local.json"

# Effective state = this project's override if it has one, else the Nix-owned
# user-scope default (cfg/skill-defaults.nix): a short always-on baseline,
# everything else off. A skill absent from BOTH is on (Claude Code's own
# absent-key-means-on rule), which also covers running before the first
# rebuild that ships the default-off overlay.
declare -A nix_off=()
if [[ -f "$user_settings" ]]; then
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    nix_off["$name"]=1
  done < <(jq -r '.skillOverrides // {} | to_entries[] | select(.value == "off") | .key' "$user_settings" 2>/dev/null || true)
fi

declare -A local_override=()
if [[ -f "$output" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    local_override["${line%%$'\t'*}"]="${line#*$'\t'}"
  done < <(jq -r '.skillOverrides // {} | to_entries[] | "\(.key)\t\(.value)"' "$output" 2>/dev/null || true)
fi

effective_on() {
  local name="$1"
  if [[ -n "${local_override[$name]:-}" ]]; then
    [[ "${local_override[$name]}" == "on" ]]
  else
    [[ -z "${nix_off[$name]:-}" ]]
  fi
}

build_lines() {
  local name marker
  for name in "${skills[@]}"; do
    if effective_on "$name"; then
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
  if effective_on "$name"; then
    preselect_chain+="pos(${idx})+select+"
  fi
done
preselect_chain+="pos(1)"

on_now=()
for name in "${skills[@]}"; do
  effective_on "$name" && on_now+=("$name")
done

header_lines=(
  "Toggle: Tab (also Shift+Tab) · select all: Ctrl-A · clear all: Ctrl-D"
  "Save: Enter (writes only what differs from the default into ./${output}) · Cancel: Esc"
  "✓ = ON for this project · unchecked = OFF · most skills default off (see cfg/skill-defaults.nix)"
)
if (( ${#on_now[@]} > 0 )); then
  header_lines+=("Currently on here: $(printf '%s, ' "${on_now[@]}" | sed 's/, $//')")
fi
header="$(printf '%s\n' "${header_lines[@]}")"

selected="$(build_lines | fzf -m \
  --prompt="Skills (select = ON)> " \
  --height=60% \
  --layout=reverse \
  --delimiter=$'\t' \
  --with-nth=1,2 \
  --nth=2 \
  --bind="ctrl-a:select-all,ctrl-d:deselect-all" \
  --bind="load:${preselect_chain}" \
  --header="$header" \
  --header-first)"
# Empty selection is valid (it means "everything off"), unlike mcp-pick where
# an empty pick has nothing useful to write -- so don't bail out on empty;
# only bail if the user hit Esc, which fzf reports as exit != 0, already
# handled by `set -e` above via the subshell's exit status.

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if ! grep -qE '(^|/)\.claude/settings\.local\.json$' .gitignore 2>/dev/null; then
    echo "Warning: .gitignore does not include .claude/settings.local.json" >&2
  fi
fi

declare -A selected_on=()
while IFS=$'\t' read -r _marker name; do
  [[ -n "$name" ]] || continue
  selected_on["$name"]=1
done <<< "$selected"

# Only write an override where the pick DIFFERS from the Nix default -- keeps
# settings.local.json down to actual exceptions instead of restating every
# skill's state every time.
overrides_json="{}"
for name in "${skills[@]}"; do
  want_on=0
  [[ -n "${selected_on[$name]:-}" ]] && want_on=1
  is_default_on=1
  [[ -n "${nix_off[$name]:-}" ]] && is_default_on=0
  if [[ "$want_on" -ne "$is_default_on" ]]; then
    value="off"
    [[ "$want_on" -eq 1 ]] && value="on"
    overrides_json="$(jq --arg k "$name" --arg v "$value" '.[$k] = $v' <<< "$overrides_json")"
  fi
done

mkdir -p "$(dirname "$output")"
[[ -f "$output" ]] || echo '{}' > "$output"

tmp="$(mktemp)"
trap 'rm -f "${tmp:-}"' EXIT
jq --argjson ov "$overrides_json" \
  'if ($ov | length) > 0 then .skillOverrides = $ov else del(.skillOverrides) end' \
  "$output" > "$tmp"
mv "$tmp" "$output"
echo "Wrote $output ($(jq 'length' <<< "$overrides_json") override(s))"
