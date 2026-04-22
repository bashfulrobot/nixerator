#!/usr/bin/env bash
# NOTE: set -euo pipefail and PATH are set by writeShellApplication.
#
# Spawn a detached `claude remote-control` server in a repo under
# $HOME/git/. Intended to be invoked from inside the always-on
# control-tower session (see apps.cli.claude-remote.controlTower) so
# that new remote sessions can be created from a phone via
# claude.ai/code without SSHing into the host.
#
# `claude remote-control` is a proper daemon: no PTY needed, a closed
# stdin is fine. We just need to detach it from our process group so
# the spawn call returns immediately.

GIT_ROOT="${HOME}/git"

# ── Colours ──────────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

info() { printf '%s▸ %s%s\n' "$CYAN" "$*" "$NC"; }
ok() { printf '%s✔ %s%s\n' "$GREEN" "$*" "$NC"; }
warn() { printf '%s⚠ %s%s\n' "$YELLOW" "$*" "$NC" >&2; }

# Single trailing key=value RESULT line for AI / scripted callers to grep.
emit_result() {
  printf 'RESULT'
  for kv in "$@"; do printf ' %s' "$kv"; done
  printf '\n'
}

emit_err() {
  local code="$1"
  shift
  local msg="$*"
  printf '%s✖ %s%s\n' "$RED" "$msg" "$NC" >&2
  emit_result "status=error" "code=${code}" "message=\"${msg}\""
}

# ── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: claude-remote [--name <name>] <repo-subpath>
       claude-remote -h | --help

Spawn a detached 'claude remote-control' server in a repo under
\$HOME/git/. The new session shows up in claude.ai/code by name so you
can attach to it from your phone.

Arguments:
  <repo-subpath>   Required. Relative path under \$HOME/git/ (e.g.
                   "hyprflake" or "nixerator/modules"), or an absolute
                   path that resolves under \$HOME/git/. Must be a git
                   repository.

Options:
  --name <name>    Name the new session. Must match [A-Za-z0-9._-]+.
                   Defaults to <basename>-<UTC-timestamp>.
  -h, --help       Show this help.

Output: every run emits a single trailing line beginning with "RESULT"
containing space-separated key=value pairs. Exit codes:
  0 ok, 1 user error, 2 spawn failure.
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

# ── start ────────────────────────────────────────────────────────────────────
cmd_start() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)
        [[ $# -ge 2 ]] || {
          emit_err BAD_ARGS "--name requires an argument"
          exit 1
        }
        name="$2"
        shift 2
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        emit_err BAD_ARGS "unknown flag: $1"
        exit 1
        ;;
      *) break ;;
    esac
  done

  [[ $# -ge 1 ]] || {
    emit_err BAD_ARGS "missing <repo-subpath>"
    exit 1
  }
  local subpath="$1"
  shift

  if [[ $# -gt 0 ]]; then
    warn "extra arguments ignored: $*  ('claude remote-control' has no initial-prompt arg; attach to the spawned session and type your prompt there)"
  fi

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

  info "Spawning remote-control server for $resolved (name=$name)"

  # Strip CLAUDE_CODE_REMOTE_* so the new server isn't confused by vars
  # inherited from the caller (which is typically itself a remote-control
  # session). Detach with setsid+nohup so the spawn returns immediately
  # and the server survives the caller exiting.
  local pid
  pid=$(
    cd "$resolved" || exit 127
    unset CLAUDE_CODE_REMOTE \
      CLAUDE_CODE_REMOTE_SESSION_ID \
      CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE \
      CLAUDE_CODE_ENTRYPOINT \
      CLAUDE_CODE_CONTAINER_ID \
      CLAUDECODE
    setsid nohup claude remote-control \
      --name "$name" \
      --spawn=session \
      --permission-mode bypassPermissions \
      </dev/null >/dev/null 2>&1 &
    printf '%s\n' "$!"
  ) || {
    emit_err SPAWN_FAILED "failed to spawn claude remote-control for $name"
    exit 2
  }

  if [[ -z "$pid" ]]; then
    emit_err SPAWN_FAILED "claude started but no pid captured for $name"
    exit 2
  fi

  ok "Session '$name' launched (pid=$pid). Open claude.ai/code on web/phone and pick the session by name."
  emit_result "status=ok" "name=$name" "pid=$pid" "dir=$resolved"
}

# ── dispatch ─────────────────────────────────────────────────────────────────
[[ $# -ge 1 ]] || {
  usage
  exit 0
}

case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  start)
    shift
    cmd_start "$@"
    ;;
  *)
    # Default action: treat argv as arguments to start.
    cmd_start "$@"
    ;;
esac
