#!/usr/bin/env bash
set -euo pipefail

mcp_dir="$HOME/.claude/mcp-servers"
if [[ ! -d "$mcp_dir" ]]; then
  echo "No MCP servers directory found at $mcp_dir" >&2
  exit 1
fi

for cmd in fzf jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd is required but not installed." >&2
    exit 1
  fi
done

mapfile -t servers < <(find "$mcp_dir" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort)
if [[ ${#servers[@]} -eq 0 ]]; then
  echo "No MCP servers found in $mcp_dir" >&2
  exit 1
fi

output=".mcp.json"

# Discover MCPs already declared in the local project's .mcp.json so the picker
# can mark them. Anything in the project but not in $mcp_dir is reported
# separately so the user knows it would be lost on overwrite.
declare -A configured=()
configured_known=()
configured_extra=()
if [[ -f "$output" ]]; then
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    configured["$name"]=1
    if [[ -d "$mcp_dir/$name" ]]; then
      configured_known+=("$name")
    else
      configured_extra+=("$name")
    fi
  done < <(jq -r '.mcpServers // {} | keys[]' "$output" 2>/dev/null || true)
fi

build_lines() {
  local name marker
  for name in "${servers[@]}"; do
    if [[ -n "${configured[$name]:-}" ]]; then
      marker="✓"
    else
      marker=" "
    fi
    # Tab-delimited so fzf can display the marker but search only the name.
    printf '%s\t%s\n' "$marker" "$name"
  done
}

header_lines=(
  "Tab: select  ·  Shift+Tab: unselect  ·  Enter: confirm  ·  Esc: cancel"
  "✓ marks servers already in ./${output}"
)
if (( ${#configured_known[@]} + ${#configured_extra[@]} > 0 )); then
  header_lines+=("Currently in ./${output}: $(printf '%s, ' "${configured_known[@]}" "${configured_extra[@]}" | sed 's/, $//')")
fi
if (( ${#configured_extra[@]} > 0 )); then
  header_lines+=("(not in ${mcp_dir}, will be dropped if overwritten: $(printf '%s, ' "${configured_extra[@]}" | sed 's/, $//'))")
fi
header="$(printf '%s\n' "${header_lines[@]}")"

selected="$(build_lines | fzf -m \
  --prompt="MCP servers> " \
  --height=60% \
  --layout=reverse \
  --delimiter=$'\t' \
  --with-nth=1,2 \
  --nth=2 \
  --header="$header" \
  --header-first)"
if [[ -z "$selected" ]]; then
  exit 1
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if ! grep -qE '(^|/)\.mcp\.json$' .gitignore 2>/dev/null; then
    echo "Warning: .gitignore does not include .mcp.json" >&2
  fi
fi

if [[ -e "$output" ]]; then
  read -r -p "${output} exists. Overwrite? [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

tmp="$(mktemp)"
trap 'rm -f "${tmp:-}" "${tmp2:-}"' EXIT
echo '{"mcpServers":{}}' > "$tmp"

while IFS=$'\t' read -r _marker name; do
  [[ -n "$name" ]] || continue
  shopt -s nullglob
  files=("$mcp_dir/$name"/.mcp*)
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No .mcp* files found for $name" >&2
    exit 1
  fi
  if [[ ${#files[@]} -gt 1 ]]; then
    echo "Multiple .mcp* files found for $name; expected one." >&2
    exit 1
  fi
  tmp2="$(mktemp)"
  jq -s '.[0].mcpServers * .[1].mcpServers | {mcpServers: .}' "$tmp" "${files[0]}" > "$tmp2"
  mv "$tmp2" "$tmp"
done <<< "$selected"

mv "$tmp" "$output"
echo "Wrote $output"
