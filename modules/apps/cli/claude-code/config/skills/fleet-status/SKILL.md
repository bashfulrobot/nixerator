---
name: fleet-status
description: Worktree-aware resume board. Enumerate every task worktree on the machine under the shared worktree root and, for each, show repo, issue number, branch, workflow step, dirty and ahead/behind counts, claim owner, and the exact `work <repo>#N` command to resume it. Flags orphaned worktrees (referenced issue is closed) and stale claims (issue claimed by another host). A worktree with no issue number is a benign "untracked" row, not an error. Read-only. Use after a reboot, or when several agents have run across many repos, to see every in-flight task and how to re-attach. The multi-worktree generalization of branch-status.
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
`<root>/<repo>/<worktree>`. Worktrees are the source of truth -- every row is a
real worktree on disk. Leftover `.setup-issue-N.lock` files are ignored (they
are not evidence of in-flight work; producer-side lock cleanup lives
elsewhere). For each worktree it reads `.worktree-state.json` and prints:

- **repo** and **issue number** (the join key)
- **branch**
- **workflow step** plus the latest `step_history` note (the breadcrumb the
  last agent left)
- **dirty** count and **ahead/behind** vs the branch base (from `base_ref`,
  else the detected default branch)
- **claim owner**
- **resume command**: `work <repo>#<N>` (or `cd <worktree>` for an untracked row)

It queries the forge for each issue's state to drive the flags. Worktrees can
span more than one git host (GitHub and a self-hosted Forgejo), so each forge
call runs with the current directory inside that worktree and `forge` detects
the host from the repo's `origin` remote. A repo on neither host, or a failed
lookup, degrades that row to issue state `unknown` rather than crashing the
listing.

## Row kinds

- **worktree**: a task worktree with a derivable issue number (from the state
  file, or from the branch/dir -- `issue-251`, `feat/251`, `feat/251-slug`,
  `251-fix`, or a bare `251`).
- **untracked**: a healthy worktree whose branch carries no issue number (a
  slug-only branch like `feat/arr-declarative-config`). This is a benign,
  first-class state -- deliberate groundwork for an issue-less sister workflow
  -- **not** an orphan. It renders as a normal row with a dim `[untracked]` tag
  and a `cd <worktree>` resume hint.

## Flags

- **ORPHAN**: a worktree whose referenced issue is **closed** on the forge --
  no open issue backs it. A numbered issue the forge cannot read (404,
  transport, or auth failure -- `forge` cannot distinguish them, all share one
  non-zero exit) degrades to issue state `unknown`, never a false orphan.
- **STALE**: a worktree whose issue is claimed by a **different host**, read
  from the issue's `<!-- worktree-flow:claim -->` lease comments (worktree-flow
  #249). The winning claim is the lowest-comment-id claim; its `host:` line is
  the owner. Absent any claim comment, the owner defaults to the local host
  (benign, since the worktree is local).

Reporting only. This skill never removes or edits a worktree, branch, issue, or
state file -- a separate reaper can act on the flags it surfaces.

## JSON schema (`--json`)

Each array element is an object:

| field | type | notes |
|-------|------|-------|
| `repo` | string | repo namespace dir |
| `issue` | number \| null | `null` for an untracked worktree |
| `branch` | string | |
| `worktree` | string | absolute path |
| `kind` | string | `"worktree"` or `"untracked"` |
| `workflow_step` | string | may be empty |
| `last_note` | string | latest `step_history` note, may be empty |
| `type` | string | issue type from the state file, may be empty |
| `dirty` | number | count of dirty paths |
| `ahead` | number \| null | commits ahead of base; `null` when uncomputable |
| `behind` | number \| null | commits behind base; `null` when uncomputable |
| `owner` | string | claiming host, else the local host |
| `issue_state` | string | `OPEN` / `CLOSED` / `unknown` |
| `orphan` | boolean | |
| `stale` | boolean | |
| `reasons` | array of string | flag explanations, possibly empty |
| `resume` | string | `work <repo>#<N>` or `cd <worktree>` |

Numeric fields are numbers or `null` -- the human board's `?` placeholder never
appears in `--json`. Control chars are stripped only on the TTY render path;
`--json` values are emitted verbatim (JSON encodes them safely).

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
- The claim owner is read from the issue's `<!-- worktree-flow:claim -->` lease
  comments (worktree-flow #249) via `forge issue-comments`; absent any claim it
  defaults to the current host, since worktrees are host-local. The foreign-host
  stale flag only fires when the winning claim's `host:` differs from this
  machine (`uname -n`). With `--no-remote`, no forge lookup runs and the owner is
  always the local host.
- To resume a flagged task, hand its `resume:` line to the user, e.g.
  `work nixerator#251`.
