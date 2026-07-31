# /auto permission model

How an autonomous run gets hands-off `rm`/`kill`/`pkill` without permanently
loosening the host, and why it is built this way. `/github-issues-auto` writes
and tears down the same sentinel (see its own SKILL.md), so everything here
applies to that skill's runs too -- there is only one gate, not one per skill.

## The problem

Three things block a clean "elevate only during /auto" on the host:

1. **Explicit `ask` rules prompt in every mode.** `rm`/`kill`/`pkill`/`sudo`
   live in `permissions.ask`. Verified against the docs: a matching `ask` rule
   prompts even under `bypassPermissions` and even when a PreToolUse hook
   returns `allow`. So no permission mode and no hook can silence an `ask`'d
   command while it stays in the `ask` list.
2. **Runtime settings edits are classifier-blocked.** The old approach wrote
   the four commands into `settings.local.json` at setup. The auto-mode
   classifier denies that as self-modification ("widening the permission
   system"), so it never worked.
3. **Native "don't ask again" grants do not reach subagents.** `/auto` does
   most work in spawned subagents, which have independent permissions. Granting
   in the main session leaves subagent commands prompting mid-run.

## The design

Make a **PreToolUse hook the sole arbiter** for `rm`/`kill`/`pkill`, gated by a
session-bound sentinel:

- The three commands are removed from the `ask` list (no sticky ask rule to
  fight) and are not in `allow` either. Nothing in settings decides them.
- `claude-auto-gate` (built from `cfg/scripts/auto-gate.sh`, wired as
  `@AUTO_GATE_COMMAND@` in `settings.json` PreToolUse) decides. First,
  independent of the sentinel: if an `rm` target resolves to a catastrophic
  path (see **The rm circuit breaker** below), deny outright. Otherwise, if
  `~/.claude/.auto-mode-active` exists AND its `session_id` matches the running
  session: `kill`/`pkill` allow unconditionally; `rm` allows only if every
  target resolves inside a safe root (see **rm scoping**). Anything that
  doesn't clear its bar returns `ask`.
- Because the decision lives in the tool pipeline, it covers the main session
  AND subagents (subagent actions go through the same rules as the parent).
- `sudo` is never touched: it stays an explicit `ask` rule and prompts in every
  mode, including mid-run. The specific sudo commands actually needed
  (`tailscale file cp`, `dmidecode`) remain individually allow-listed.

## rm scoping

`kill`/`pkill` have no filesystem path to scope by, so a matching sentinel
allows them against any process -- unchanged from the original design. `rm` is
different: even with a matching sentinel, every target in the command has to
resolve inside one of three kinds of safe root, or the whole command falls
through to `ask`.

1. **The session's own working tree.** The hook reads `.cwd` from its own
   payload (the same field `precompact-checkpoint.sh` already relies on, not
   this subprocess's own `$PWD`, which the harness makes no guarantee
   matches). If that cwd sits inside a git repo or linked worktree, the safe
   root is `git rev-parse --show-toplevel` from there -- the whole checkout,
   not just wherever cwd happens to be nested. If it isn't a repo (a plain
   scratch dir), the safe root is the cwd itself. Whatever folder or repo the
   autonomous run is actually working in becomes its own blast-radius
   boundary; nothing outside it is touched without a prompt.
2. **Pre-authorized folders.** One absolute path per line in
   `~/.claude/auto-safe-roots` (`#`-comments and blank lines ignored), read
   fresh on every check -- no rebuild to add or remove one. An entry that is
   itself catastrophic (see below), or too shallow to be a meaningful scope
   (fewer than 3 path segments, e.g. bare `/home/dustin`), is silently
   ignored rather than honoured: the file can widen the grant, but can't be
   used to accidentally hand out the world.
3. **Universal scratch roots.** `/tmp`, `~/.claude/jobs` (background job
   scratch), and `~/.claude/autonomous-runs` (this skill's own log dir) are
   always safe regardless of cwd.

A target the hook can't confidently resolve -- most commonly a relative path
in a command that also `cd`/`pushd`s elsewhere, so the real execution-order
cwd isn't the session's own -- is treated as unsafe rather than guessed. This
can only ever cost an unnecessary `ask`; it can never turn into a wrong
`allow`. This parser is deliberately narrower than
`guard-primary-tree-write.sh`'s full cd-replay engine: an absolute or
`~`-prefixed target always resolves regardless of surrounding `cd` noise,
since it doesn't depend on cwd.

## The rm circuit breaker

A short list of catastrophic targets denies `rm` outright: bare `/`, bare
`$HOME`, and system roots (`/etc`, `/boot`, `/nix`, `/usr`, `/var`, `/root`,
`/sys`, `/proc`, `/bin`, `/sbin`, `/lib`, `/lib64`), plus any other user's home
under `/home`. This check runs before the sentinel is even consulted, so it
holds with no active `/auto` session, with one active, and regardless of what
the pre-authorized-folders file says -- a bad entry there (even a literal `/`)
gets filtered on load (see **rm scoping** above) and, as a second layer, could
never grant more than the circuit breaker independently denies anyway. A hook
`deny` can never be overridden by another hook's `allow`, so this composes
safely with the scoped-elevation logic above it. `$HOME`'s own subtree is
judged by the safe-root logic, not this list -- only the bare path is
catastrophic, so ordinary work under `$HOME/git` etc. still routes through the
normal scoped-elevation/ask path instead of a hard deny.

## Lifecycle

- **Up front:** `/auto` asks one consent question. On grant it writes the
  sentinel (with `$CLAUDE_CODE_SESSION_ID`). That is the only prompt.
  `/github-issues-auto` writes the same sentinel without asking -- invoking
  that skill is itself the consent, since its own contract is zero gates
  from the first message (see its SKILL.md).
- **During:** the hook auto-allows `kill`/`pkill` unconditionally and `rm`
  within its scoped safe roots, for this session only.
- **End:** teardown does `rm -f ~/.claude/.auto-mode-active`. Removing the
  sentinel is the entire revoke -- nothing was written to a permission store.
- **Crash:** a leftover sentinel is inert in any other session (session-id
  binding) and is swept by the next `/auto` run (`references/overlay.md`).

## What stays enforced no matter what

- The `permissions.deny` list (`nixos-rebuild`, `nix-collect-garbage`) -- a hook
  `allow` cannot override a deny.
- The git guard hook (`--no-verify`, `--force`).
- The rm circuit breaker (see above) -- unlike everything else in this file,
  this one holds even with no `/auto` or `/github-issues-auto` session active.
- An `rm` target outside the session's working tree, the pre-authorized
  folders, and the universal scratch roots -- it still prompts, sentinel or
  not.
- `sudo` prompts.

## Tradeoff to know

Because the hook is the sole arbiter for these three commands, "don't ask again"
no longer permanently silences them in normal sessions -- the hook re-asks each
time outside an auto run. That is deliberate: `rm`/`kill`/`pkill` are confirmed
in interactive use and skipped only inside a consented, session-scoped auto run
(and, for `rm`, only inside that run's own working tree or an explicitly
pre-authorized folder). To permanently allow a specific pattern regardless of
session state, add it to `permissions.allow` in `settings.json` instead.
