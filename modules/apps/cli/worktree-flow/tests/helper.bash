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
