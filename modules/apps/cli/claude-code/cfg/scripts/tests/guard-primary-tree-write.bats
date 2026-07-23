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
  for verb in commit push reset merge rebase revert cherry-pick am apply add rm mv clean; do
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
  for verb in commit push reset merge rebase revert cherry-pick am apply add rm mv clean; do
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

@test "sanction marker (leading the command) allows a primary-checkout write" {
  # /commit emits the marker as the first token of the command, one git write
  # per Bash call, so these are the forms the override must honour.
  local fails=0 cmd
  for cmd in \
    "CLAUDE_SANCTIONED_GIT=1 git -C $PRIMARY commit -m x" \
    "CLAUDE_SANCTIONED_GIT=1 git -C $PRIMARY add -- foo.txt" \
    "CLAUDE_SANCTIONED_GIT=1 git -C $PRIMARY push && CLAUDE_SANCTIONED_GIT=1 git -C $PRIMARY push --tags"; do
    if [ "$(decision "$cmd")" != allow ]; then
      echo "EXPECTED ALLOW, GOT DENY: $cmd"
      fails=$((fails + 1))
    fi
  done
  [ "$fails" -eq 0 ]
}

@test "marker mentioned in a commit message does not sanction the write" {
  # The marker quoted inside a commit message must NOT sanction the write, even
  # after a shell metacharacter that grep cannot tell from real command
  # structure. The message sits after the verb, outside the matched segment, so
  # the commit still resolves to the primary tree and denies.
  local fails=0 cmd
  for cmd in \
    "git -C $PRIMARY commit -m \"(CLAUDE_SANCTIONED_GIT=1 was discussed)\"" \
    "git -C $PRIMARY commit -m \"note; CLAUDE_SANCTIONED_GIT=1 git add\"" \
    "git -C $PRIMARY commit -m \"the marker (CLAUDE_SANCTIONED_GIT=1 git ...) frees it\""; do
    if [ "$(decision "$cmd")" != deny ]; then
      echo "EXPECTED DENY, GOT ALLOW: $cmd"
      fails=$((fails + 1))
    fi
  done
  [ "$fails" -eq 0 ]
}

@test "marker on a non-leading line of a multiline command does not sanction" {
  # grep '^' is per-line; the hook uses bash '=~' whose '^' is string-start, so
  # an unmarked primary write on line 1 is not freed by a marker on a later line.
  local cmd
  cmd="git -C $PRIMARY commit -m wip"$'\n'"CLAUDE_SANCTIONED_GIT=1 git status"
  [ "$(decision "$cmd")" = deny ]
}

@test "resolves the tree per verb-bearing invocation in a mixed compound" {
  local fails=0
  # verb-bearing git targets the worktree; the primary git is a read, so allow.
  if [ "$(decision "git -C $PRIMARY log --oneline && git -C $WT commit -m x")" != allow ]; then
    echo "EXPECTED ALLOW, GOT DENY: primary-read && worktree-commit"
    fails=$((fails + 1))
  fi
  # verb-bearing git targets the primary; the worktree git is a read, so deny.
  if [ "$(decision "git -C $WT log && git -C $PRIMARY commit -m x")" != deny ]; then
    echo "EXPECTED DENY, GOT ALLOW: worktree-read && primary-commit"
    fails=$((fails + 1))
  fi
  [ "$fails" -eq 0 ]
}

@test "replays sequential cds so the last one before the write wins" {
  # A later cd into the primary is the tree the bare commit actually lands in, so
  # resolving against the first cd would wrongly allow it. The verb-bearing git
  # has no -C of its own; the cd in effect when it runs (into the primary) counts.
  local fails=0
  if [ "$(decision "cd $WT && git status && cd $PRIMARY && git commit -m x")" != deny ]; then
    echo "EXPECTED DENY, GOT ALLOW: cd worktree, read, cd primary, commit"
    fails=$((fails + 1))
  fi
  # Mirror image: first cd into the primary, then into the worktree before the
  # only mutating git. The cd in effect at the commit is the worktree, so allow.
  if [ "$(decision "cd $PRIMARY && git log && cd $WT && git commit -m x")" != allow ]; then
    echo "EXPECTED ALLOW, GOT DENY: cd primary, read, cd worktree, commit"
    fails=$((fails + 1))
  fi
  [ "$fails" -eq 0 ]
}

@test "replays subshell scope so both cd/subshell mirrors resolve correctly" {
  # A `( ... )` cwd change is discarded at the closing `)`. The two mirror forms
  # both land the write in the primary and must both deny:
  #   - the commit AFTER the group runs where the outer cd left it (primary);
  #   - the commit INSIDE the group runs where the inner cd put it (primary).
  # A textual nearest-cd heuristic gets exactly one of these wrong, so the replay
  # is what makes both correct.
  local fails=0
  if [ "$(decision "cd $PRIMARY && (cd $WT && git status) && git commit -m x")" != deny ]; then
    echo "EXPECTED DENY, GOT ALLOW: commit after subshell, outer cd primary"
    fails=$((fails + 1))
  fi
  if [ "$(decision "cd $WT && (cd $PRIMARY && git commit -m x)")" != deny ]; then
    echo "EXPECTED DENY, GOT ALLOW: commit inside subshell, inner cd primary"
    fails=$((fails + 1))
  fi
  # A worktree write inside a subshell entered from the primary still allows.
  if [ "$(decision "cd $PRIMARY && (cd $WT && git commit -m x)")" != allow ]; then
    echo "EXPECTED ALLOW, GOT DENY: commit inside subshell, inner cd worktree"
    fails=$((fails + 1))
  fi
  [ "$fails" -eq 0 ]
}

@test "resolves the cd path past leading options and tracks pushd/popd" {
  # cd flags (-P, -L, --) must be skipped so the path, not the flag, is the
  # target; otherwise `git -C -P` errors and fails open on a primary write.
  # pushd/popd move the cwd via a directory stack and must be replayed: after
  # popd the cwd returns to what it was before the matching pushd.
  local fails=0 cmd
  for cmd in \
    "cd -P $PRIMARY && git commit -m x" \
    "cd -- $PRIMARY && git commit -m x" \
    "pushd $PRIMARY && git commit -m x" \
    "cd $PRIMARY && pushd $WT && popd && git commit -m x"; do
    if [ "$(decision "$cmd")" != deny ]; then
      echo "EXPECTED DENY, GOT ALLOW: $cmd"
      fails=$((fails + 1))
    fi
  done
  for cmd in \
    "cd -P $WT && git commit -m x" \
    "cd $WT && pushd $PRIMARY && popd && git commit -m x"; do
    if [ "$(decision "$cmd")" != allow ]; then
      echo "EXPECTED ALLOW, GOT DENY: $cmd"
      fails=$((fails + 1))
    fi
  done
  [ "$fails" -eq 0 ]
}

@test "denies wrapper- and env-assignment-prefixed git in the primary checkout" {
  # A git write behind sudo/env/time or a bare env-assignment (including a
  # backdating GIT_AUTHOR_DATE=) must still be caught, not slip the anchor.
  local fails=0 cmd
  for cmd in \
    "sudo git -C $PRIMARY commit -m x" \
    "env GIT_AUTHOR_NAME=x git -C $PRIMARY commit -m x" \
    "time git -C $PRIMARY commit -m x" \
    "GIT_AUTHOR_DATE=2020-01-01 git -C $PRIMARY commit -m x"; do
    if [ "$(decision "$cmd")" != deny ]; then
      echo "EXPECTED DENY, GOT ALLOW: $cmd"
      fails=$((fails + 1))
    fi
  done
  [ "$fails" -eq 0 ]
}

@test "denies a primary write at non-obvious command positions and wrappers" {
  # The verb anchor must treat every shell command position as such, not just
  # ; & | ( backtick. A brace group, a compound-command head (if/while), the
  # command/exec/xargs wrappers, and a backslash-escaped git all run git in the
  # current tree, so a primary write through any of them must deny.
  local fails=0 cmd
  for cmd in \
    "{ git -C $PRIMARY commit -m x; }" \
    "if git -C $PRIMARY commit -m x; then :; fi" \
    "while git -C $PRIMARY commit -m x; do :; done" \
    "command git -C $PRIMARY commit -m x" \
    "\\git -C $PRIMARY commit -m x" \
    "true | xargs git -C $PRIMARY commit -m"; do
    if [ "$(decision "$cmd")" != deny ]; then
      echo "EXPECTED DENY, GOT ALLOW: $cmd"
      fails=$((fails + 1))
    fi
  done
  [ "$fails" -eq 0 ]
}

@test "resolves repeated -C cumulatively, honouring the last effective tree" {
  # git applies multiple -C in order, each relative to the previous, so the last
  # absolute -C wins. Reading only the first -C would allow a primary write that
  # names a worktree first.
  local fails=0
  if [ "$(decision "git -C $WT -C $PRIMARY commit -m x")" != deny ]; then
    echo "EXPECTED DENY, GOT ALLOW: -C worktree -C primary commit"
    fails=$((fails + 1))
  fi
  if [ "$(decision "git -C $PRIMARY -C $WT commit -m x")" != allow ]; then
    echo "EXPECTED ALLOW, GOT DENY: -C primary -C worktree commit"
    fails=$((fails + 1))
  fi
  [ "$fails" -eq 0 ]
}

@test "sanction marker frees only the invocation it directly leads" {
  local fails=0
  # A marked read (or write) must not free a later unmarked primary write in the
  # same command; the unmarked commit still denies.
  if [ "$(decision "CLAUDE_SANCTIONED_GIT=1 git status && git -C $PRIMARY commit -m x")" != deny ]; then
    echo "EXPECTED DENY, GOT ALLOW: marked read then unmarked primary commit"
    fails=$((fails + 1))
  fi
  # The genuinely marked write is still allowed.
  if [ "$(decision "CLAUDE_SANCTIONED_GIT=1 git -C $PRIMARY commit -m x")" != allow ]; then
    echo "EXPECTED ALLOW, GOT DENY: marked primary commit"
    fails=$((fails + 1))
  fi
  # The marker frees the invocation it leads even when a cd precedes it, since it
  # directly prefixes that git write (what a user-directed flow may emit).
  if [ "$(decision "cd $PRIMARY && CLAUDE_SANCTIONED_GIT=1 git commit -m x")" != allow ]; then
    echo "EXPECTED ALLOW, GOT DENY: cd then marked primary commit"
    fails=$((fails + 1))
  fi
  # The marker cannot be smuggled through a -c option value; it only counts when
  # it leads the invocation, not when it rides inside a later flag.
  if [ "$(decision "git -c foo=CLAUDE_SANCTIONED_GIT=1 -C $PRIMARY commit -m x")" != deny ]; then
    echo "EXPECTED DENY, GOT ALLOW: marker smuggled in -c value"
    fails=$((fails + 1))
  fi
  [ "$fails" -eq 0 ]
}

@test "allows non-mutating and excluded git verbs in the primary checkout" {
  local fails=0 cmd
  for cmd in \
    "git -C $PRIMARY status" \
    "git -C $PRIMARY diff" \
    "git -C $PRIMARY log --oneline" \
    "git -C $PRIMARY blame foo.txt" \
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
