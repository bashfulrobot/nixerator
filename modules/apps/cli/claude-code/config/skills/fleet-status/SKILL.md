---
name: fleet-status
description: Worktree-aware resume board. Enumerate every task worktree on the machine under the shared worktree root and, for each, show repo, issue number, branch, workflow step, dirty and ahead/behind counts, claim owner, and the exact `work <repo>#N` command to resume it. Flags orphaned worktrees (no matching open issue) and stale claims (owned by another host, or issue closed). Read-only. Use after a reboot, or when several agents have run across many repos, to see every in-flight task and how to re-attach. The multi-worktree generalization of branch-status.
disable-model-invocation: true
allowed-tools: ["Bash", "Read"]
---

## What this is

`branch-status` reports a single branch in the current directory. `fleet-status`
generalizes it to every task worktree on the machine. After a reboot, or once
several agents have run across many repos, this is the one read-only view of
what is in flight, where each task lives, which issue it claims, and how to
pick it back up.

## Process

Run the bundled script and read the board back to the user:

```bash
scripts/fleet-status.sh
```

It walks the shared worktree root (`$WORKTREE_ROOT`, default
`$HOME/git/.worktrees`), which uses a per-repo namespaced layout of
`<root>/<repo>/<worktree>`. For each worktree it reads `.worktree-state.json`
and prints:

- **repo** and **issue number** (the join key)
- **branch**
- **workflow step** plus the latest `step_history` note (the breadcrumb the
  last agent left)
- **dirty** count and **ahead/behind** vs the branch base (from `base_ref`,
  else the detected default branch)
- **claim owner**
- **resume command**: `work <repo>#<N>`

It queries the forge for each issue's state to drive the flags. Worktrees can
span more than one git host (GitHub and a self-hosted Forgejo), so each
`forge issue-json` runs with the current directory inside that worktree and
`forge` detects the host from the repo's `origin` remote. A repo on neither
host, or a failed lookup, degrades that row to issue state `unknown` rather
than crashing the listing.

## Flags

- **ORPHAN**: a worktree (or a leftover `.setup-issue-N.lock` claim) with no
  matching open issue -- nothing backing it on the forge.
- **STALE**: a claim whose owner is not the current host, or whose issue is
  closed on the forge.

Reporting only. This skill never removes or edits a worktree, branch, issue, or
state file -- a separate reaper can act on the flags it surfaces.

## Options

```bash
scripts/fleet-status.sh --json        # machine-readable array instead of the board
scripts/fleet-status.sh --no-remote   # skip forge lookups (offline / fast)
scripts/fleet-status.sh --root PATH   # scan a different worktree root
scripts/fleet-status.sh --help
```

## Notes

- Read-only and no fetch: ahead/behind is computed against local
  remote-tracking refs, so run a `git fetch` first if you need those counts
  fresh. The script itself never mutates anything.
- The claim owner is read from an explicit lease field on the state file when
  present; otherwise it defaults to the current host, since worktrees are
  host-local. The foreign-host stale flag only fires when a state file records
  an owner different from this machine.
- To resume a flagged task, hand its `resume:` line to the user, e.g.
  `work nixerator#251`.
