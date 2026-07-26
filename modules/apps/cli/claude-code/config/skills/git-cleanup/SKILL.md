---
name: git-cleanup
description: >-
  Standing authorization to finish a branch end to end: commit, push, open a PR,
  squash-merge to main, delete the remote branch, remove the worktree. Fires on
  "git cleanup", "clean up the git stuff", "wrap this branch up", or an
  unambiguous equivalent. That phrase IS the in-turn merge authorization, so do
  not re-confirm and do not hand back a command. Does not fire on a bare "push
  this" or "open a PR", which stop before merging.
allowed-tools: ["Bash", "Read", "Grep"]
---

# Git Cleanup (phrase-triggered)

When I say "git cleanup" (or an unambiguous equivalent, e.g. "clean up the git stuff", "wrap this branch up"), treat it as my standing, explicit authorization to, in order:

1. Make sure the current work is committed and pushed, opening a PR if one doesn't exist yet.
2. Merge that PR into `main` (squash, delete the remote branch). This phrase itself is the explicit, in-turn request that satisfies the merge-authorization rule above: don't re-confirm, and don't hand back a command instead of running it, background session or not.
3. Remove the worktree(s) and local branch(es) tied to that work.

- This phrase is scoped to whatever we were just working on, not a sweep of every stale worktree or open PR in the repo. If it's ambiguous which branch I mean, ask.
- Outside of this phrase, the default still holds: push the branch and open a PR, but stop there, don't merge unprompted.

## The rule this refers to

The "merge-authorization rule above" is the one that stays resident in
`~/.claude/CLAUDE.md` under **Merge and push-to-main authorization**: merging a
PR into `main` or pushing straight to `main` is authorized only when Dustin
explicitly asks for that specific action in the same turn. The "git cleanup"
phrase is exactly such an ask, which is why steps 1–3 run without further
confirmation.

Force-pushes and other destructive git operations (`git reset --hard`,
discarding branches) remain a separate, narrower case and still need explicit
confirmation even inside this workflow.

## Provider note

Dustin uses two git hosts — GitHub and a self-hosted Forgejo at
`git.srvrs.co`. Use the provider-aware `forge` helper rather than assuming
`gh`, and check the repo's remote before picking a CLI.
