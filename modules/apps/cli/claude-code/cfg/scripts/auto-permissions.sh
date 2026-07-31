# auto-permissions: manage /auto and /github-issues-auto's global permission
# state -- the pre-authorized-folders file auto-gate.sh reads
# (auto/references/permission-model.md, "rm scoping"), and the session
# sentinel's status.
#
# Validation rules mirror auto-gate.sh's is_catastrophic/depth_ok exactly (a
# deliberate second copy, not a shared lib -- two occurrences is under this
# repo's three-occurrence DRY threshold, and keeping both inline makes each
# script's actual behavior auditable on its own). If those rules change in
# auto-gate.sh, update them here too.
#
# wired onto PATH as `auto-permissions` (default.nix).

set -euo pipefail

home="${HOME:-/root}"
config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
roots_file="${config_dir}/auto-safe-roots"
sentinel="${config_dir}/.auto-mode-active"

usage() {
  cat <<'EOF'
auto-permissions -- manage /auto and /github-issues-auto's global permission state

Usage:
  auto-permissions list                 List pre-authorized folders and their validity
  auto-permissions add <path>           Pre-authorize a folder for scoped rm elevation
  auto-permissions remove <path>        Remove a pre-authorized folder
  auto-permissions status               Show whether an autonomous session sentinel is active

Pre-authorized folders live in $CLAUDE_CONFIG_DIR/auto-safe-roots (one per
line). They only ever widen WHERE rm can run during an active /auto or
/github-issues-auto session -- they grant nothing outside one, and a
catastrophic target (bare /, bare $HOME, system roots) is always denied
regardless. Full model: config/skills/auto/references/permission-model.md.
EOF
}

path_has_prefix() {
  local path="$1" prefix="$2"
  [[ "$path" == "$prefix" || "$path" == "$prefix"/* ]]
}

is_catastrophic() {
  local p="$1" root
  [[ "$p" == "/" ]] && return 0
  [[ "$p" == "$home" ]] && return 0
  for root in /etc /boot /nix /usr /var /root /sys /proc /bin /sbin /lib /lib64; do
    path_has_prefix "$p" "$root" && return 0
  done
  if path_has_prefix "$p" /home && ! path_has_prefix "$p" "$home"; then
    return 0
  fi
  return 1
}

depth_ok() {
  local p="${1#/}" slashes
  slashes="${p//[^\/]/}"
  [[ "${#slashes}" -ge 2 ]]
}

# Print every non-comment, non-blank line's realpath -m resolution, one per
# input line (blank output for a line that fails to resolve).
resolved_entries() {
  [[ -f "$roots_file" ]] || return 0
  local line
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "$line" ]] || continue
    realpath -m -- "$line" 2>/dev/null || true
  done <"$roots_file"
}

cmd_list() {
  if [[ ! -s "$roots_file" ]]; then
    echo "No pre-authorized folders configured ($roots_file does not exist or is empty)."
    return 0
  fi
  local resolved status
  while IFS= read -r resolved; do
    [[ -n "$resolved" ]] || continue
    status="active"
    if is_catastrophic "$resolved"; then
      status="IGNORED (catastrophic -- auto-gate.sh will never honour this)"
    elif ! depth_ok "$resolved"; then
      status="IGNORED (too shallow -- fewer than 3 path segments)"
    fi
    printf '%s -- %s\n' "$resolved" "$status"
  done < <(resolved_entries)
}

cmd_add() {
  local raw="${1:-}"
  [[ -n "$raw" ]] || {
    echo "usage: auto-permissions add <path>" >&2
    exit 1
  }
  local entry
  entry="$(realpath -m -- "$raw")"

  if is_catastrophic "$entry"; then
    echo "Refusing to add $entry: this is a catastrophic path (bare /, bare \$HOME, or a system root). auto-gate.sh's circuit breaker denies rm against it unconditionally, and would silently ignore this entry anyway -- adding it would just be misleading." >&2
    exit 1
  fi
  if ! depth_ok "$entry"; then
    echo "Refusing to add $entry: too shallow, fewer than 3 path segments (too close to a whole-drive scope). auto-gate.sh would silently ignore this entry." >&2
    exit 1
  fi

  local existing
  while IFS= read -r existing; do
    if [[ "$existing" == "$entry" ]]; then
      echo "Already pre-authorized: $entry"
      return 0
    fi
  done < <(resolved_entries)

  mkdir -p "$config_dir"
  printf '%s\n' "$entry" >>"$roots_file"
  echo "Pre-authorized: $entry"
  echo "Only takes effect during an active /auto or /github-issues-auto session; rm elsewhere still prompts as normal."
}

cmd_remove() {
  local raw="${1:-}"
  [[ -n "$raw" ]] || {
    echo "usage: auto-permissions remove <path>" >&2
    exit 1
  }
  local entry
  entry="$(realpath -m -- "$raw")"

  if [[ ! -f "$roots_file" ]]; then
    echo "Nothing to remove: $roots_file does not exist."
    return 0
  fi

  local tmp removed line stripped resolved
  tmp="$(mktemp)"
  removed="false"
  while IFS= read -r line; do
    stripped="${line%%#*}"
    stripped="${stripped#"${stripped%%[![:space:]]*}"}"
    stripped="${stripped%"${stripped##*[![:space:]]}"}"
    if [[ -n "$stripped" ]]; then
      resolved="$(realpath -m -- "$stripped" 2>/dev/null || true)"
      if [[ -n "$resolved" && "$resolved" == "$entry" ]]; then
        removed="true"
        continue
      fi
    fi
    printf '%s\n' "$line" >>"$tmp"
  done <"$roots_file"
  mv "$tmp" "$roots_file"

  if [[ "$removed" == true ]]; then
    echo "Removed: $entry"
  else
    echo "Not found in $roots_file: $entry"
  fi
}

cmd_status() {
  if [[ ! -f "$sentinel" ]]; then
    echo "No autonomous session sentinel active (~/.auto-mode-active does not exist)."
    return 0
  fi
  local sid goal started this_sid
  sid="$(jq -r '.session_id // empty' "$sentinel" 2>/dev/null || true)"
  goal="$(jq -r '.goal // empty' "$sentinel" 2>/dev/null || true)"
  started="$(jq -r '.started // empty' "$sentinel" 2>/dev/null || true)"
  this_sid="${CLAUDE_CODE_SESSION_ID:-}"

  echo "Sentinel present: $sentinel"
  [[ -n "$goal" ]] && echo "  goal: $goal"
  [[ -n "$started" ]] && echo "  started: $started"
  echo "  session id: ${sid:-unknown}"

  if [[ -n "$this_sid" && -n "$sid" && "$this_sid" == "$sid" ]]; then
    echo "Active for THIS session -- rm/kill/pkill are elevated per the scoping rules above."
  else
    echo "Does NOT match this session (or this session's id is unavailable) -- inert here. If this is a stale leftover from a crashed run, clear it with: rm -f $sentinel"
  fi
}

case "${1:-}" in
  list) cmd_list ;;
  add) cmd_add "${2:-}" ;;
  remove) cmd_remove "${2:-}" ;;
  status) cmd_status ;;
  -h | --help | help | "") usage ;;
  *)
    echo "Unknown subcommand: $1" >&2
    usage >&2
    exit 1
    ;;
esac
