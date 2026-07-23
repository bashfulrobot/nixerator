# Shared bats helper for the github-issue setup branch-existence preflight (#262).
#
# Sources lib.sh + github-issue.sh (functions only) inside a throwaway git
# fixture, so detect_existing_branch can be exercised against real local and
# remote refs without a network or the real repo. Sourcing rather than executing
# means BASH_SOURCE[0] != $0, which is exactly what the script's dispatch guard
# keys on, so the file defines its functions without running a subcommand. The
# fixture is a bare "origin" repo plus a working clone: a branch pushed to origin
# is visible to `git ls-remote origin`, a local branch shows in `git show-ref`.
TESTS_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
SCRIPTS_DIR="$(cd "${TESTS_DIR}/../scripts" && pwd)"

# Isolate every git call in the fixture from the developer's / CI runner's global
# and system git config, so a stray commit.gpgsign, init.templateDir, or hook
# cannot turn an environment problem into a spurious test failure.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null

setup_fixture() {
  FIX="$(mktemp -d)"
  git init -q --bare "${FIX}/origin.git"
  git clone -q "${FIX}/origin.git" "${FIX}/work" 2>/dev/null
  git -C "${FIX}/work" config user.email t@t
  git -C "${FIX}/work" config user.name t
  git -C "${FIX}/work" commit -q --allow-empty -m init
  git -C "${FIX}/work" push -q origin HEAD:main
}

rm_fixture() { [ -n "${FIX:-}" ] && rm -rf "${FIX}"; }

# detect BRANCH — run detect_existing_branch from inside the fixture working
# clone, under the same `set -euo pipefail` the packaged command runs with, so
# the test catches set -e footguns the raw source would otherwise hide. stderr
# (the offline warning) is dropped so $output is exactly the function's result.
detect() {
  ( cd "${FIX}/work" || exit 3
    bash -c '
      set -euo pipefail
      source "'"${SCRIPTS_DIR}"'/lib.sh"
      source "'"${SCRIPTS_DIR}"'/github-issue.sh"
      detect_existing_branch "$1"
    ' _ "$1" 2>/dev/null )
}

# push_remote_only BRANCH — create BRANCH, push it to origin, then delete the
# local copy so only the remote ref remains.
push_remote_only() {
  git -C "${FIX}/work" branch "$1"
  git -C "${FIX}/work" push -q origin "$1"
  git -C "${FIX}/work" branch -D "$1"
}

# qstate_at DIR ARGS... — run cmd_queue_state from DIR under the same
# `set -euo pipefail` and _JSON_MODE=1 the packaged command uses. stdout is the
# structured JSON result (or {"error":...} on failure); stderr (the human log
# lines) is dropped so $output is exactly the JSON. Exit code is preserved.
qstate_at() {
  local dir="$1"
  shift
  ( cd "$dir" || exit 3
    bash -c '
      set -euo pipefail
      source "'"${SCRIPTS_DIR}"'/lib.sh"
      source "'"${SCRIPTS_DIR}"'/github-issue.sh"
      _JSON_MODE=1
      cmd_queue_state "$@"
    ' _ "$@" 2>/dev/null )
}

# qstate ARGS... — the common case: run from inside the fixture work tree.
qstate() { qstate_at "${FIX}/work" "$@"; }

# queue_state_file — absolute path to the .queue-state.json the fixture clone
# resolves to, for tests that inspect or corrupt it directly.
queue_state_file() {
  ( cd "${FIX}/work" || exit 3
    bash -c '
      source "'"${SCRIPTS_DIR}"'/lib.sh"
      printf "%s/.queue-state.json" "$(worktree_base)"
    ' )
}

# state_build ARGS... — run create_issue_state with the given args (sourced, no
# network), so the resumed/fresh state file it writes can be inspected. Args are
# passed straight through: branch wt_path issue title body base_ref [blockers]
# [pr_url] [initial_step] [setup_note].
state_build() {
  ( bash -c '
      set -euo pipefail
      source "'"${SCRIPTS_DIR}"'/lib.sh"
      source "'"${SCRIPTS_DIR}"'/github-issue.sh"
      create_issue_state "$@"
    ' _ "$@" 2>/dev/null )
}

# resume_fn FUNC ARGS... — run a pure github-issue.sh helper (no cwd, no
# network) and print its stdout.
resume_fn() {
  ( bash -c '
      set -euo pipefail
      source "'"${SCRIPTS_DIR}"'/lib.sh"
      source "'"${SCRIPTS_DIR}"'/github-issue.sh"
      f="$1"; shift; "$f" "$@"
    ' _ "$@" 2>/dev/null )
}

# ahead_in_fixture BRANCH — run count_ahead_of_origin from the fixture work
# clone (needs the origin remote-tracking ref that setup_fixture creates).
ahead_in_fixture() {
  ( cd "${FIX}/work" || exit 3
    bash -c '
      set -euo pipefail
      source "'"${SCRIPTS_DIR}"'/lib.sh"
      source "'"${SCRIPTS_DIR}"'/github-issue.sh"
      count_ahead_of_origin "$1"
    ' _ "$1" 2>/dev/null )
}

# behind_in_fixture BRANCH — run count_behind_of_origin from the fixture work
# clone.
behind_in_fixture() {
  ( cd "${FIX}/work" || exit 3
    bash -c '
      set -euo pipefail
      source "'"${SCRIPTS_DIR}"'/lib.sh"
      source "'"${SCRIPTS_DIR}"'/github-issue.sh"
      count_behind_of_origin "$1"
    ' _ "$1" 2>/dev/null )
}

# resume_wt_add BRANCH_STATE AHEAD BRANCH WT_PATH — run add_resume_worktree from
# the fixture work clone (real git, no gh/network) so the per-state worktree-add
# routing and the missing-tracking-ref guard can be pinned. Exit status is the
# function's return (0 success, 2 unknown state, 3 origin ref did not resolve).
resume_wt_add() {
  ( cd "${FIX}/work" || exit 3
    bash -c '
      set -euo pipefail
      source "'"${SCRIPTS_DIR}"'/lib.sh"
      source "'"${SCRIPTS_DIR}"'/github-issue.sh"
      add_resume_worktree "$1" "$2" "$3" "$4"
    ' _ "$1" "$2" "$3" "$4" 2>/dev/null )
}
