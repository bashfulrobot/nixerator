# /auto permission model

How an autonomous run gets hands-off `rm`/`kill`/`pkill` without permanently
loosening the host, and why it is built this way.

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
  `@AUTO_GATE_COMMAND@` in `settings.json` PreToolUse) decides: if
  `~/.claude/.auto-mode-active` exists AND its `session_id` matches the running
  session, return `allow`; otherwise return `ask`.
- Because the decision lives in the tool pipeline, it covers the main session
  AND subagents (subagent actions go through the same rules as the parent).
- `sudo` is never touched: it stays an explicit `ask` rule and prompts in every
  mode, including mid-run. The specific sudo commands actually needed
  (`tailscale file cp`, `dmidecode`) remain individually allow-listed.

## Lifecycle

- **Up front:** `/auto` asks one consent question. On grant it writes the
  sentinel (with `$CLAUDE_CODE_SESSION_ID`). That is the only prompt.
- **During:** the hook auto-allows the three commands for this session only.
- **End:** teardown does `rm -f ~/.claude/.auto-mode-active`. Removing the
  sentinel is the entire revoke -- nothing was written to a permission store.
- **Crash:** a leftover sentinel is inert in any other session (session-id
  binding) and is swept by the next `/auto` run (`references/overlay.md`).

## What stays enforced no matter what

- The `permissions.deny` list (`nixos-rebuild`, `nix-collect-garbage`) -- a hook
  `allow` cannot override a deny.
- The git guard hook (`--no-verify`, `--force`).
- The `rm -rf ~` / `rm -rf /` circuit breaker.
- `sudo` prompts.

## Tradeoff to know

Because the hook is the sole arbiter for these three commands, "don't ask again"
no longer permanently silences them in normal sessions -- the hook re-asks each
time outside an auto run. That is deliberate: `rm`/`kill`/`pkill` are confirmed
in interactive use and skipped only inside a consented, session-scoped auto run.
To permanently allow a specific pattern, add it to `permissions.allow` in
`settings.json`.
