#!/usr/bin/env bash
set -euo pipefail

mcp_dir="$HOME/.claude/mcp-servers"
if [[ ! -d "$mcp_dir" ]]; then
  echo "No MCP servers directory found at $mcp_dir" >&2
  exit 1
fi

if ! command -v fzf >/dev/null 2>&1; then
  echo "fzf is required but not installed." >&2
  exit 1
fi

mapfile -t servers < <(find "$mcp_dir" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort)
if [[ ${#servers[@]} -eq 0 ]]; then
  echo "No MCP servers found in $mcp_dir" >&2
  exit 1
fi

selected="$(printf '%s\n' "${servers[@]}" | fzf -m --prompt="MCP servers> " --height=40% --layout=reverse)"
if [[ -z "$selected" ]]; then
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not installed." >&2
  exit 1
fi

output=".mcp.json"
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
echo '{"mcpServers":{}}' > "$tmp"

while IFS= read -r name; do
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
