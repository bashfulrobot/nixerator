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

mapfile -t all_servers < <(find "$mcp_dir" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort)
if [[ ${#all_servers[@]} -eq 0 ]]; then
  echo "No MCP servers found in $mcp_dir" >&2
  exit 1
fi

# Servers whose $mcp_dir/<name>/.mcp.json carries a live, already-substituted
# secret (cfg/mcp-servers.nix's secretServerNames, plus opentabs which
# activation.nix bridges the same way). Their file is deliberately kept out
# of the Nix store and written at 0600 -- but a project's ./.mcp.json has
# neither guarantee: it can be group/world-readable, and this repo's own
# projects are routinely Syncthing-synced across machines. Merging one of
# these in copies the real secret out of its 0600 home into that wider
# exposure, which is exactly how a live Konnect PAT + Tableau PAT ended up
# sitting in plaintext in ~/dev/kong/.mcp.json (2026-09-16). Keep this list
# in sync with secretServerNames in cfg/mcp-servers.nix.
secret_servers=(kong-konnect tableau context7 opentabs)
is_secret_server() {
  local name="$1" s
  for s in "${secret_servers[@]}"; do
    [[ "$name" == "$s" ]] && return 0
  done
  return 1
}

servers=()
hidden=()
for name in "${all_servers[@]}"; do
  if is_secret_server "$name"; then
    hidden+=("$name")
  else
    servers+=("$name")
  fi
done
if [[ ${#servers[@]} -eq 0 ]]; then
  echo "No pickable MCP servers found in $mcp_dir (all present servers carry live secrets, see below)" >&2
  exit 1
fi
if [[ ${#hidden[@]} -gt 0 ]]; then
  echo "Hiding secret-bearing servers from the picker: ${hidden[*]}" >&2
  echo "  These already carry a live, resolved credential in their $mcp_dir/<name>/.mcp.json (0600)." >&2
  echo "  Merging one into a project ./.mcp.json would copy that credential out of its 0600 home" >&2
  echo "  into a file with no permission or sync guarantee. kong-konnect never needs picking --" >&2
  echo "  it's already registered at user scope (see mcp-servers.nix's userScopeTemplate)." >&2
  echo "  For the others, reference the server manually with a \${VAR}-style placeholder instead" >&2
  echo "  of picking it here, or ask for a per-project registration approach that doesn't require" >&2
  echo "  plaintext secret duplication." >&2
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
    # Hidden secret servers count as "extra" too: they're a real directory
    # under $mcp_dir, but not in the pickable `servers` list above, so an
    # overwrite would silently drop them same as anything else not offered.
    if [[ -d "$mcp_dir/$name" ]] && ! is_secret_server "$name"; then
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

# Pre-select rows already in ./.mcp.json so the fzf selection (>) starts in
# sync with the ✓ markers. From there, Tab/Shift+Tab toggles add or remove.
preselect_chain=""
idx=0
for name in "${servers[@]}"; do
  idx=$((idx + 1))
  if [[ -n "${configured[$name]:-}" ]]; then
    preselect_chain+="pos(${idx})+select+"
  fi
done
preselect_chain+="pos(1)"

header_lines=(
  "Add: Tab (toggles current row, also Shift+Tab) · select all: Ctrl-A · clear all: Ctrl-D"
  "Save: Enter (writes ./${output} with the selected set) · Cancel: Esc"
  "✓ = already in ./${output} (pre-selected — deselect to drop it, select others to add)"
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
  --bind="ctrl-a:select-all,ctrl-d:deselect-all" \
  --bind="load:${preselect_chain}" \
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
