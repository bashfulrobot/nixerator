#!/usr/bin/env bats
# Regression tests for git-sync.sh, the SessionStart hook that reports (and,
# in a linked worktree only, aligns) a checkout's relationship to its
# upstream branch.
#
# The bug this fixes: the original hook ran `git reset "origin/$branch"`
# (mixed) unconditionally whenever local was purely behind, with no regard
# for whether the checkout was the shared PRIMARY tree or a linked worktree,
# and no dirty-tree check. A mixed reset never rewrites files on disk -- it
# only moves HEAD and the index -- so it silently fast-forwards HEAD past a
# commit that changed some file while leaving that file's stale pre-commit
# content in place. Every diff/status tool afterward reports the file as
# "modified", indistinguishable from a hand-authored revert of that commit.
# These cases pin: the primary checkout never resets (report-only), a linked
# worktree still auto-aligns when clean, a dirty worktree skips the
# auto-align instead of reproducing the same illusion one level down, and the
# pre-existing diverged/ahead/up-to-date branches are unchanged.

HOOK="${BATS_TEST_DIRNAME}/../git-sync.sh"

# $ORIGIN is a bare remote. $PRIMARY is its primary clone (git-dir ==
# git-common-dir). $WT is a linked worktree off $PRIMARY (git-dir !=
# git-common-dir). tracked.txt is the file whose content the "looks like a
# revert" illusion depends on.
setup() {
  ORIGIN="${BATS_TEST_TMPDIR}/origin.git"
  PRIMARY="${BATS_TEST_TMPDIR}/primary"
  WT="${BATS_TEST_TMPDIR}/wt"
  git init -q --bare -b main "$ORIGIN"

  git clone -q "$ORIGIN" "$PRIMARY"
  git -C "$PRIMARY" config user.email t@t.t
  git -C "$PRIMARY" config user.name t
  echo "v1" > "$PRIMARY/tracked.txt"
  git -C "$PRIMARY" add -A
  git -C "$PRIMARY" commit -q -m base
  git -C "$PRIMARY" push -q origin main

  git -C "$PRIMARY" worktree add -q -b side "$WT" >/dev/null 2>&1
  # $WT's branch needs its own upstream on $ORIGIN -- without this, "origin/side"
  # doesn't exist, the hook's git-log comparisons fail, and every worktree test
  # below silently no-ops before it ever reaches the reset/no-reset decision.
  git -C "$WT" push -q -u origin side
}

# Advance $ORIGIN's <branch> past $PRIMARY's/$WT's local copy by one commit
# that changes tracked.txt, without touching $PRIMARY's or $WT's working
# copy -- this is what "local is purely behind" looks like from either
# checkout. Defaults to main (what most tests exercise from $PRIMARY);
# worktree tests pass "side" explicitly.
advance_origin() {
  local branch="${1:-main}"
  local scratch="${BATS_TEST_TMPDIR}/scratch-$branch"
  git clone -q -b "$branch" "$ORIGIN" "$scratch"
  git -C "$scratch" config user.email t@t.t
  git -C "$scratch" config user.name t
  echo "v2" > "$scratch/tracked.txt"
  git -C "$scratch" commit -q -am advance
  git -C "$scratch" push -q origin "$branch"
}

# Run the hook with cwd=$1, discarding its stdin requirement (the hook reads
# none, matching reminders.sh and the original ad-hoc hook).
run_hook() {
  (cd "$1" && bash "$HOOK") 2>&1
}

@test "primary checkout: purely behind, clean tree -- reports, never resets" {
  advance_origin
  local head_before out
  head_before="$(git -C "$PRIMARY" rev-parse HEAD)"
  out="$(run_hook "$PRIMARY")"
  [[ "$out" == *"Primary checkout is 1 commit(s) behind"* ]]
  [[ "$out" == *"not auto-aligning"* ]]
  [ "$(git -C "$PRIMARY" rev-parse HEAD)" = "$head_before" ]
  [ "$(cat "$PRIMARY/tracked.txt")" = "v1" ]
}

@test "primary checkout: purely behind, DIRTY tree -- still never resets (primary wins over dirty check)" {
  advance_origin
  echo "local edit" > "$PRIMARY/tracked.txt"
  local head_before out
  head_before="$(git -C "$PRIMARY" rev-parse HEAD)"
  out="$(run_hook "$PRIMARY")"
  [[ "$out" == *"Primary checkout"* ]]
  [ "$(git -C "$PRIMARY" rev-parse HEAD)" = "$head_before" ]
  [ "$(cat "$PRIMARY/tracked.txt")" = "local edit" ]
}

@test "linked worktree: purely behind, clean tree -- auto-aligns" {
  advance_origin side
  local out
  out="$(run_hook "$WT")"
  [[ "$out" == *"Aligned git state with origin/side"* ]]
  [ "$(git -C "$WT" rev-parse HEAD)" = "$(git -C "$ORIGIN" rev-parse side)" ]
}

@test "linked worktree: purely behind, DIRTY tree -- does not auto-align" {
  advance_origin side
  echo "wip edit" >> "$WT/tracked.txt"
  local head_before out
  head_before="$(git -C "$WT" rev-parse HEAD)"
  out="$(run_hook "$WT")"
  [[ "$out" == *"not auto-aligning"* ]]
  [[ "$out" == *"uncommitted change"* ]]
  [ "$(git -C "$WT" rev-parse HEAD)" = "$head_before" ]
}

@test "reports diverged state without resetting, in the primary checkout" {
  advance_origin
  echo "local-only" >> "$PRIMARY/tracked.txt"
  git -C "$PRIMARY" commit -q -am local-only-commit
  local head_before out
  head_before="$(git -C "$PRIMARY" rev-parse HEAD)"
  out="$(run_hook "$PRIMARY")"
  [[ "$out" == *"Diverged"* ]]
  [ "$(git -C "$PRIMARY" rev-parse HEAD)" = "$head_before" ]
}

@test "reports unpushed local commits without resetting" {
  echo "local-only" >> "$PRIMARY/tracked.txt"
  git -C "$PRIMARY" commit -q -am local-only-commit
  local head_before out
  head_before="$(git -C "$PRIMARY" rev-parse HEAD)"
  out="$(run_hook "$PRIMARY")"
  [[ "$out" == *"Unpushed local commits"* ]]
  [ "$(git -C "$PRIMARY" rev-parse HEAD)" = "$head_before" ]
}

@test "silent when already up to date" {
  local out
  out="$(run_hook "$PRIMARY")"
  [ -z "$out" ]
}

@test "exits quietly outside a git repo" {
  local nonrepo="${BATS_TEST_TMPDIR}/nonrepo"
  mkdir -p "$nonrepo"
  run bash -c "cd '$nonrepo' && bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
