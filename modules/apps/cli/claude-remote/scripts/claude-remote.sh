#!/usr/bin/env bash
# NOTE: set -euo pipefail and PATH are set by writeShellApplication

GIT_ROOT="${HOME}/git"
UNIT_PREFIX="claude-remote-"

# ── Colours ──────────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

info() { printf '%s▸ %s%s\n' "$CYAN" "$*" "$NC"; }
ok()   { printf '%s✔ %s%s\n' "$GREEN" "$*" "$NC"; }
warn() { printf '%s⚠ %s%s\n' "$YELLOW" "$*" "$NC" >&2; }
die()  { printf '%s✖ %s%s\n' "$RED" "$*" "$NC" >&2; exit 1; }

# Single trailing key=value RESULT line for AI / scripted callers to grep.
emit_result() {
  printf 'RESULT'
  for kv in "$@"; do printf ' %s' "$kv"; done
  printf '\n'
}

emit_err() {
  local code="$1"; shift
  local msg="$*"
  printf '%s✖ %s%s\n' "$RED" "$msg" "$NC" >&2
  emit_result "status=error" "code=${code}" "message=\"${msg}\""
}

# ── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: claude-remote <subcommand> [args]

Manage Claude Code remote-control sessions launched as transient
systemd --user services. Designed to be called from inside another
Claude Code session (or any local shell) to spawn ad-hoc sessions
in repos under \$HOME/git/.

Subcommands:
  start [--name <name>] <repo-subpath> [prompt...]
      Launch a new remote-control session in \$HOME/git/<repo-subpath>.
      If --name is omitted, defaults to <basename>-<UTC-timestamp>.
      The session appears in claude.ai/code under the chosen name.

  list
      List all running claude-remote-* user units.

  status <name>
      Show systemd status for the named session.

  stop <name>
      Stop the named session (terminates the underlying claude
      process; the remote-control session in the web UI ends).

  resume <name>
      Print URL / instructions for re-attaching from claude.ai/code
      or your phone. Remote-control sessions are not resumed via
      the local CLI.

  -h, --help
      Show this help.

Output: every command emits a single trailing line beginning with
"RESULT" containing space-separated key=value pairs, suitable for
parsing by an AI caller. Exit codes:
  0 ok, 1 user error, 2 systemd/claude failure, 3 not found.
EOF
}

# ── Helpers ──────────────────────────────────────────────────────────────────
resolve_target() {
  local subpath="$1"
  local target
  if [[ "$subpath" = /* ]]; then
    target="$subpath"
  else
    target="$GIT_ROOT/$subpath"
  fi
  realpath -m -- "$target"
}

is_under_git_root() {
  local path="$1"
  case "$path" in
    "$GIT_ROOT" | "$GIT_ROOT"/*) return 0 ;;
    *) return 1 ;;
  esac
}

unit_for_name() {
  printf '%s%s.service' "$UNIT_PREFIX" "$1"
}

unit_exists() {
  systemctl --user list-units --all --no-legend --plain "$1" 2>/dev/null | grep -q .
}

# ── start ────────────────────────────────────────────────────────────────────
cmd_start() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)
        [[ $# -ge 2 ]] || { emit_err BAD_ARGS "--name requires an argument"; exit 1; }
        name="$2"; shift 2 ;;
      -h | --help)
        usage; exit 0 ;;
      --) shift; break ;;
      -*) emit_err BAD_ARGS "unknown flag: $1"; exit 1 ;;
      *) break ;;
    esac
  done

  [[ $# -ge 1 ]] || { emit_err BAD_ARGS "start requires <repo-subpath>"; exit 1; }
  local subpath="$1"; shift
  local prompt="$*"

  local resolved
  resolved="$(resolve_target "$subpath")"

  if ! is_under_git_root "$resolved"; then
    emit_err PATH_OUTSIDE_GIT_ROOT "$resolved is not under $GIT_ROOT"
    exit 1
  fi
  if [[ ! -d "$resolved" ]]; then
    emit_err DIR_NOT_FOUND "$resolved does not exist"
    exit 1
  fi
  if ! git -C "$resolved" rev-parse --git-dir >/dev/null 2>&1; then
    emit_err NOT_A_GIT_REPO "$resolved is not a git repository"
    exit 1
  fi

  if [[ -z "$name" ]]; then
    name="$(basename "$resolved")-$(date -u +%Y%m%dT%H%M%SZ)"
  fi
  if [[ ! "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
    emit_err BAD_NAME "name must match [A-Za-z0-9._-]+ (got: $name)"
    exit 1
  fi

  local unit
  unit="$(unit_for_name "$name")"

  if systemctl --user is-active --quiet "$unit" 2>/dev/null; then
    emit_err NAME_IN_USE "unit $unit is already active; pick another --name"
    exit 1
  fi
  systemctl --user reset-failed "$unit" 2>/dev/null || true

  info "Spawning remote-control session for $resolved (name=$name)"

  local -a claude_args=(--remote-control --name "$name")
  [[ -n "$prompt" ]] && claude_args+=("$prompt")

  # Strip CLAUDE_CODE_REMOTE_* env so the spawned `claude` is not detected
  # as "inside a remote session" (which makes --remote-control refuse).
  # The systemd --user manager normally does not propagate calling-shell
  # env, but UnsetEnvironment is defensive in case the manager itself was
  # started with these set (e.g., from the control-tower service).
  if ! systemd-run --user \
         --unit="$unit" \
         --description="Claude Code remote-control session: $name" \
         --working-directory="$resolved" \
         -p "UnsetEnvironment=CLAUDE_CODE_REMOTE CLAUDE_CODE_REMOTE_SESSION_ID CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_CONTAINER_ID CLAUDECODE" \
         -p "StandardInput=null" \
         -p "StandardOutput=journal" \
         -p "StandardError=journal" \
         --no-block \
         claude "${claude_args[@]}" >/dev/null 2>&1; then
    emit_err SYSTEMD_RUN_FAILED "systemd-run --user failed for $unit (check: systemctl --user status $unit)"
    exit 2
  fi

  ok "Session '$name' launched. Open claude.ai/code on web/phone and pick the session by name."
  emit_result "status=ok" "name=$name" "unit=$unit" "dir=$resolved"
}

# ── list ─────────────────────────────────────────────────────────────────────
cmd_list() {
  local lines
  lines="$(systemctl --user list-units --type=service --all --no-legend --plain "${UNIT_PREFIX}*.service" 2>/dev/null || true)"
  if [[ -z "$lines" ]]; then
    info "no claude-remote sessions found"
    emit_result "status=ok" "count=0"
    return 0
  fi
  printf '%s\n' "$lines"
  local count
  count="$(printf '%s\n' "$lines" | wc -l | tr -d ' ')"
  emit_result "status=ok" "count=$count"
}

# ── status ───────────────────────────────────────────────────────────────────
cmd_status() {
  [[ $# -ge 1 ]] || { emit_err BAD_ARGS "status requires <name>"; exit 1; }
  local name="$1"
  local unit
  unit="$(unit_for_name "$name")"

  if ! unit_exists "$unit"; then
    emit_err NOT_FOUND "no session named $name (unit $unit)"
    exit 3
  fi

  systemctl --user status --no-pager "$unit" || true
  local active
  active="$(systemctl --user is-active "$unit" 2>/dev/null || true)"
  emit_result "status=ok" "name=$name" "unit=$unit" "active=$active"
}

# ── stop ─────────────────────────────────────────────────────────────────────
cmd_stop() {
  [[ $# -ge 1 ]] || { emit_err BAD_ARGS "stop requires <name>"; exit 1; }
  local name="$1"
  local unit
  unit="$(unit_for_name "$name")"

  if ! unit_exists "$unit"; then
    emit_err NOT_FOUND "no session named $name (unit $unit)"
    exit 3
  fi

  if ! systemctl --user stop "$unit" >/dev/null 2>&1; then
    emit_err STOP_FAILED "systemctl --user stop $unit failed"
    exit 2
  fi
  systemctl --user reset-failed "$unit" 2>/dev/null || true

  ok "Session '$name' stopped."
  emit_result "status=ok" "name=$name" "unit=$unit"
}

# ── resume ───────────────────────────────────────────────────────────────────
cmd_resume() {
  [[ $# -ge 1 ]] || { emit_err BAD_ARGS "resume requires <name>"; exit 1; }
  local name="$1"
  local unit
  unit="$(unit_for_name "$name")"

  if ! unit_exists "$unit"; then
    emit_err NOT_FOUND "no session named $name (unit $unit)"
    exit 3
  fi

  cat <<EOF
To re-attach to session '$name':
  • Web:   open https://claude.ai/code and pick the session by name.
  • Phone: open the Claude app and select '$name' from the session list.
  • Logs:  journalctl --user -u $unit -f
EOF
  emit_result "status=ok" "name=$name" "unit=$unit"
}

# ── dispatch ─────────────────────────────────────────────────────────────────
[[ $# -ge 1 ]] || { usage; exit 0; }

sub="$1"; shift
case "$sub" in
  start)     cmd_start "$@" ;;
  list)      cmd_list "$@" ;;
  status)    cmd_status "$@" ;;
  stop)      cmd_stop "$@" ;;
  resume)    cmd_resume "$@" ;;
  -h | --help) usage; exit 0 ;;
  *) emit_err BAD_ARGS "unknown subcommand: $sub"; exit 1 ;;
esac
