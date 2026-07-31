---
name: auto-permissions
description: >-
  Manage /auto and /github-issues-auto's global permission state: the
  pre-authorized-folders list that widens where rm can run during an
  autonomous session, and the session sentinel's status. Use when the user
  wants to pre-authorize, allowlist, or trust a folder for autonomous rm
  ahead of time, asks what's currently pre-authorized, asks whether an
  autonomous session is active or whether a stale sentinel is stuck, or says
  things like "always allow rm in <folder> during /auto", "add this to my
  auto-safe-roots", "what folders can /auto touch", "is auto mode still on".
  Not for granting rm access outside of an autonomous session -- that always
  prompts, by design; this only manages what happens once one is already
  active.
---

# Auto Permissions

Thin wrapper skill around the `auto-permissions` CLI (on PATH), which reads
and writes `$CLAUDE_CONFIG_DIR/auto-safe-roots` and inspects
`$CLAUDE_CONFIG_DIR/.auto-mode-active`. Full model, including why each rule
exists: `../auto/references/permission-model.md`.

## What this does and does not control

Pre-authorizing a folder here never grants anything by itself. It only widens
**where** `rm` is allowed to run once a `/auto` or `/github-issues-auto`
session's sentinel is already active — outside one, `rm` still prompts
exactly as today, regardless of what's in the list. A catastrophic target
(bare `/`, bare `$HOME`, system roots, another user's home) is denied
outright no matter what's pre-authorized. `kill`/`pkill` aren't affected by
this file at all — they're unconditional once a sentinel is active, unscoped
by design (no filesystem path to scope a process signal by).

## Commands

```bash
auto-permissions list                 # every entry + whether auto-gate.sh will honour it
auto-permissions add <path>           # pre-authorize a folder (validates first, refuses silently-ignored entries)
auto-permissions remove <path>        # drop a folder from the list
auto-permissions status               # is a sentinel active, and does it belong to this session
```

`add` and `remove` resolve the path with `realpath -m` first (symlinks and
relative paths included), so pass whatever the user said and let the CLI
normalize it — don't pre-resolve it yourself.

## Guidance for each request shape

- **"Always allow rm in X during auto runs."** `auto-permissions add <X>`.
  If it refuses (catastrophic or too-shallow), relay the exact reason — don't
  retry with a workaround; the refusal mirrors what `auto-gate.sh` would
  silently ignore anyway, so honoring it is the only outcome that matches
  reality. Common shallow miss: the user names a whole home directory or a
  bare top-level folder — ask what subfolder they actually meant, or suggest
  their `~/git` checkout / worktree if that's what they're describing (which
  is already covered dynamically per-session and doesn't need pre-authorizing
  at all — see below).
- **"What can /auto touch right now?"** `auto-permissions list`, plus a
  one-line reminder that the *current* session's own working tree (repo/
  worktree toplevel, or the cwd if it isn't a repo) is always in scope too,
  dynamically, even with an empty list — pre-authorization is for folders
  *outside* whatever the session happens to be sitting in.
- **"Is auto mode on / why did rm just prompt anyway?"**
  `auto-permissions status`. If it reports no sentinel or a mismatched one,
  that's exactly why elevation didn't apply — say so plainly, and mention
  `rm -f ~/.claude/.auto-mode-active` only if the user wants to clear a
  confirmed-stale one themselves (don't run it unprompted; a sentinel from a
  session that's still genuinely running is not yours to clear).
- **"Stop allowing rm in X."** `auto-permissions remove <X>`.

## Not in scope (yet)

There's no equivalent global-approval mechanism for anything other than `rm`
— `kill`/`pkill` are already unscoped once a sentinel is active, `sudo`
always prompts, and `permissions.deny` (`nixos-rebuild`, `nix-collect-garbage`,
etc.) is fixed in `settings.json` and out of this skill's reach on purpose. If
the user asks for a different kind of global auto-approval, say plainly that
today's mechanism only covers `rm`'s pre-authorized-folders list, rather than
improvising a new one.
