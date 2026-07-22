#!/usr/bin/env bats
# Regression tests for guard-primary-tree-write.sh, the PreToolUse deny hook that
# blocks agent git writes (commit/push/reset/merge/rebase/cherry-pick/add) in the
# shared PRIMARY checkout while allowing them in linked worktrees (issue #264).
#
# The hook is a set of matchers plus a git-dir vs git-common-dir comparison, so it
# rots in both directions: a loosened verb pattern that stops denying a primary
# commit, or a detection bug that starts denying writes in a real worktree. These
# cases pin a real primary repo and a real linked worktree, plus the sanction
# marker bypass and the fail-open stance.

HOOK="${BATS_TEST_DIRNAME}/../guard-primary-tree-write.sh"

# A real primary checkout ($PRIMARY) with a linked worktree ($WT) hanging off it,
# so git-dir vs git-common-dir resolves the way the hook depends on.
setup() {
  PRIMARY="${BATS_TEST_TMPDIR}/primary"
  WT="${BATS_TEST_TMPDIR}/wt"
  git init -q -b main "$PRIMARY"
  git -C "$PRIMARY" config user.email t@t.t
  git -C "$PRIMARY" config user.name t
  git -C "$PRIMARY" commit -q --allow-empty -m init
  git -C "$PRIMARY" worktree add -q -b side "$WT" >/dev/null 2>&1
}

# Echo the hook's decision (deny/allow) for a given command string.
decision() {
  local json out
  json="$(jq -nc --arg c "$1" '{tool_input:{command:$c}}')"
  out="$(printf '%s' "$json" | bash "$HOOK" 2>/dev/null)"
  if grep -q '"permissionDecision": *"deny"' <<<"$out"; then echo deny; else echo allow; fi
}

@test "denies each mutating git verb in the primary checkout" {
  local fails=0 verb cmd
  for verb in commit push reset merge rebase cherry-pick add; do
    cmd="git -C $PRIMARY $verb"
    if [ "$(decision "$cmd")" != deny ]; then
      echo "EXPECTED DENY, GOT ALLOW: $cmd"
      fails=$((fails + 1))
    fi
  done
  # cd-prefix form, option-prefixed form, and a subshell form.
  for cmd in \
    "cd $PRIMARY && git commit -m x" \
    "git -C $PRIMARY -c core.hooksPath=/dev/null commit -m x" \
    "git -C $PRIMARY add -- foo.txt"; do
    if [ "$(decision "$cmd")" != deny ]; then
      echo "EXPECTED DENY, GOT ALLOW: $cmd"
      fails=$((fails + 1))
    fi
  done
  [ "$fails" -eq 0 ]
}

@test "allows the same writes in a linked worktree" {
  local fails=0 verb cmd
  for verb in commit push reset merge rebase cherry-pick add; do
    cmd="git -C $WT $verb"
    if [ "$(decision "$cmd")" != allow ]; then
      echo "EXPECTED ALLOW, GOT DENY: $cmd"
      fails=$((fails + 1))
    fi
  done
  if [ "$(decision "cd $WT && git commit -m x")" != allow ]; then
    echo "EXPECTED ALLOW, GOT DENY: cd worktree commit"
    fails=$((fails + 1))
  fi
  [ "$fails" -eq 0 ]
}

@test "sanction marker allows a primary-checkout write" {
  local fails=0 cmd
  for cmd in \
    "CLAUDE_SANCTIONED_GIT=1 git -C $PRIMARY commit -m x" \
    "cd $PRIMARY && CLAUDE_SANCTIONED_GIT=1 git commit -m x" \
    "CLAUDE_SANCTIONED_GIT=1 git -C $PRIMARY add -- foo.txt"; do
    if [ "$(decision "$cmd")" != allow ]; then
      echo "EXPECTED ALLOW, GOT DENY: $cmd"
      fails=$((fails + 1))
    fi
  done
  [ "$fails" -eq 0 ]
}

@test "allows non-mutating and excluded git verbs in the primary checkout" {
  local fails=0 cmd
  for cmd in \
    "git -C $PRIMARY status" \
    "git -C $PRIMARY diff" \
    "git -C $PRIMARY log --oneline" \
    "git -C $PRIMARY pull --ff-only origin main" \
    "git -C $PRIMARY fetch origin" \
    "git -C $PRIMARY branch -d side"; do
    if [ "$(decision "$cmd")" != allow ]; then
      echo "EXPECTED ALLOW, GOT DENY: $cmd"
      fails=$((fails + 1))
    fi
  done
  [ "$fails" -eq 0 ]
}

@test "fails open outside a repo and on non-git commands" {
  local fails=0 cmd
  for cmd in \
    "git -C ${BATS_TEST_TMPDIR}/nope commit -m x" \
    "echo git commit" \
    "npm run commit" \
    "grep -r 'git add' ."; do
    if [ "$(decision "$cmd")" != allow ]; then
      echo "EXPECTED ALLOW, GOT DENY: $cmd"
      fails=$((fails + 1))
    fi
  done
  [ "$fails" -eq 0 ]
}
