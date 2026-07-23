#!/usr/bin/env bats
# Regression tests for guard-primary-tree-write.sh, the PreToolUse deny hook that
# blocks agent git writes (commit/push/reset/merge/rebase/cherry-pick/add/rm/mv/
# clean) in the shared PRIMARY checkout while allowing them in linked worktrees
# (issue #264).
#
# The hook is a set of matchers plus a git-dir vs git-common-dir comparison, so it
# rots in both directions: a loosened verb pattern that stops denying a primary
# commit, or an anchor bug that starts denying a git verb merely quoted in prose.
# These cases pin a real primary repo, a real linked worktree, the sanction-marker
# bypass and its false positives, and the fail-open stance.
#
# decision() runs the hook from $NONREPO (a non-repo dir the test controls), so a
# case with no explicit target dir resolves against a known non-repo cwd rather
# than wherever the suite happens to run from. That keeps the fail-open and prose
# cases testing the hook's logic, not the harness location.

HOOK="${BATS_TEST_DIRNAME}/../guard-primary-tree-write.sh"

# A real primary checkout ($PRIMARY) with a linked worktree ($WT) hanging off it,
# plus a non-repo dir ($NONREPO) used as the neutral cwd for decision().
setup() {
  PRIMARY="${BATS_TEST_TMPDIR}/primary"
  WT="${BATS_TEST_TMPDIR}/wt"
  NONREPO="${BATS_TEST_TMPDIR}/nonrepo"
  mkdir -p "$NONREPO"
  git init -q -b main "$PRIMARY"
  git -C "$PRIMARY" config user.email t@t.t
  git -C "$PRIMARY" config user.name t
  git -C "$PRIMARY" commit -q --allow-empty -m init
  git -C "$PRIMARY" worktree add -q -b side "$WT" >/dev/null 2>&1
}

# Echo the hook's decision (deny/allow) for a given command string, run from a
# controlled non-repo cwd.
decision() {
  local json out
  json="$(jq -nc --arg c "$1" '{tool_input:{command:$c}}')"
  out="$(cd "$NONREPO" && printf '%s' "$json" | bash "$HOOK" 2>/dev/null)"
  if grep -q '"permissionDecision": *"deny"' <<<"$out"; then echo deny; else echo allow; fi
}

@test "denies each mutating git verb in the primary checkout" {
  local fails=0 verb cmd
  for verb in commit push reset merge rebase cherry-pick add rm mv clean; do
    cmd="git -C $PRIMARY $verb"
    if [ "$(decision "$cmd")" != deny ]; then
      echo "EXPECTED DENY, GOT ALLOW: $cmd"
      fails=$((fails + 1))
    fi
  done
  # cd-prefix, option-prefixed, subshell, and backticked forms all resolve to the
  # primary tree and must deny.
  for cmd in \
    "cd $PRIMARY && git commit -m x" \
    "git -C $PRIMARY -c core.hooksPath=/dev/null commit -m x" \
    "git -C $PRIMARY add -- foo.txt" \
    "\$(git -C $PRIMARY commit -m x)" \
    "echo start; \`git -C $PRIMARY reset --hard\`"; do
    if [ "$(decision "$cmd")" != deny ]; then
      echo "EXPECTED DENY, GOT ALLOW: $cmd"
      fails=$((fails + 1))
    fi
  done
  [ "$fails" -eq 0 ]
}

@test "denies primary writes that target the tree via --git-dir/--work-tree" {
  local fails=0 cmd
  for cmd in \
    "git --git-dir=$PRIMARY/.git --work-tree=$PRIMARY commit -m x" \
    "git --git-dir $PRIMARY/.git add -- foo.txt"; do
    if [ "$(decision "$cmd")" != deny ]; then
      echo "EXPECTED DENY, GOT ALLOW: $cmd"
      fails=$((fails + 1))
    fi
  done
  [ "$fails" -eq 0 ]
}

@test "allows the same writes in a linked worktree" {
  local fails=0 verb cmd
  for verb in commit push reset merge rebase cherry-pick add rm mv clean; do
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

@test "marker only counts when it leads a real git command" {
  # The marker text merely mentioned inside a commit message must NOT sanction
  # the write; the git commit still resolves to the primary tree and denies.
  local cmd="git -C $PRIMARY commit -m \"(CLAUDE_SANCTIONED_GIT=1 was discussed)\""
  [ "$(decision "$cmd")" = deny ]
}

@test "allows non-mutating and excluded git verbs in the primary checkout" {
  local fails=0 cmd
  for cmd in \
    "git -C $PRIMARY status" \
    "git -C $PRIMARY diff" \
    "git -C $PRIMARY log --oneline" \
    "git -C $PRIMARY pull --ff-only origin main" \
    "git -C $PRIMARY fetch origin" \
    "git -C $PRIMARY branch -d side" \
    "git -C $PRIMARY checkout main" \
    "git -C $PRIMARY restore --staged foo.txt"; do
    if [ "$(decision "$cmd")" != allow ]; then
      echo "EXPECTED ALLOW, GOT DENY: $cmd"
      fails=$((fails + 1))
    fi
  done
  [ "$fails" -eq 0 ]
}

@test "does not match a git verb quoted or echoed in prose" {
  # These sit in the primary tree's ambient reach but touch nothing, so the
  # anchor must let them through rather than hard-block an echo or a note.
  local fails=0 cmd
  for cmd in \
    "cd $PRIMARY && echo git commit" \
    "cd $PRIMARY && echo 'next step: git add the file'" \
    "cd $PRIMARY && printf 'run git commit\n' > notes.txt" \
    "cd $PRIMARY && grep -r 'git push' ."; do
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
