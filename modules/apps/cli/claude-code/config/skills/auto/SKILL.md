---
name: auto
description: >-
  Mark this session as fully autonomous. Use when the user types "/auto",
  says "run autonomously", "I'm AFK", "while I'm away", "hands-off this",
  or provides a verifiable goal condition. Prompts ONCE up front to elevate
  rm/kill/pkill to no-prompt for this session via a sentinel-gated PreToolUse
  hook (sudo still prompts; deny-list and git guards stay enforced), suppresses
  AskUserQuestion in gated skills for the rest of the run, and iterates until
  the goal condition exits 0 or the session is genuinely blocked. Auto-reverts
  on exit. Never auto-merges PRs.
argument-hint: "<goal-shell-command>"
allowed-tools: ["Bash", "Read", "Edit", "Write", "Skill", "Agent", "AskUserQuestion"]
---

# Autonomous Session

You are now operating in autonomous mode. The user is unavailable for the
duration of the run. Treat their absence as load-bearing -- after the single
setup consent prompt below, never call AskUserQuestion again, never stop to
confirm, never ask "should I continue?". Make decisions and proceed.

## Argument

`$ARGUMENTS` is a shell command. Success = exits 0. That is the only
termination contract. If `$ARGUMENTS` is empty, abort with instruction to
the user to provide a goal condition.

## Permission model

This run does NOT edit any settings file (that trips the auto-mode classifier).
It writes a session-bound sentinel, `~/.claude/.auto-mode-active`. A Nix-managed
PreToolUse hook (`claude-auto-gate`) reads it: while the sentinel is present AND
its session id matches the running session, `rm`/`kill`/`pkill` are auto-allowed
(no prompt, including inside subagents); otherwise they prompt as normal. `sudo`
is never elevated here, and the `deny` list + git guards remain absolute.
Removing the sentinel at teardown is the entire revoke. Full design and
rationale: `references/permission-model.md`.

## Setup (mandatory, in order)

1. **Stale-sentinel check.** If `~/.claude/.auto-mode-active` exists, a prior
   `/auto` run crashed without teardown. Run the cleanup in
   `references/overlay.md` before proceeding.

2. **Up-front consent prompt (the ONLY AskUserQuestion of the run).** Ask the
   user once whether to elevate `rm`/`kill`/`pkill` to no-prompt for this
   session. State plainly: `sudo` still prompts, the `deny` list and git guards
   stay enforced, and the grant is removed when the run ends. Offer two options:
   "Grant for this run" and "Keep prompting me".
   - If "Keep prompting me": skip step 3 (write no sentinel). The run still
     proceeds autonomously, but `rm`/`kill`/`pkill` will prompt normally -- warn
     that this can stall a genuinely unattended run.

3. **Write the sentinel** (only if consent was granted). The session id binds
   the grant to THIS session, so a stale sentinel can never elevate another:
   ```bash
   jq -nc --arg sid "$CLAUDE_CODE_SESSION_ID" --arg pid "$$" --arg goal "$ARGUMENTS" \
     '{session_id: $sid, pid: $pid, goal: $goal, started: now}' \
     > ~/.claude/.auto-mode-active
   ```

4. **Export the gating env var.** Subprocesses and gated skills key off this to
   suppress their own AskUserQuestion calls for the run:
   ```bash
   export CLAUDE_AUTO_MODE=1
   ```

5. **Create the run log:**
   ```bash
   mkdir -p ~/.claude/autonomous-runs
   log=~/.claude/autonomous-runs/$(date -u +%Y%m%dT%H%M%SZ).md
   ```

## Loop

1. Run `$ARGUMENTS`. If exit 0, jump to **Teardown** with `outcome=satisfied`.
2. Decide and execute the next action toward the goal. Append a one-line
   entry to `$log`: timestamp, action, reasoning.
3. Re-run `$ARGUMENTS`. If exit 0, jump to **Teardown** with `outcome=met`.
4. If the same fix has been tried twice without progress, jump to **Teardown**
   with `outcome=blocked`, reason `loop-detected`.
5. If you genuinely cannot proceed (missing credentials, conflicting
   requirements with no safe default, external system unreachable), jump
   to **Teardown** with `outcome=blocked` and the reason.
6. Otherwise: go to step 2.

## Teardown (always run -- success, blocked, or error)

1. Write final report to `$log` with: outcome, files touched, decisions made.
2. Revoke the elevation and clear the run flag:
   ```bash
   rm -f ~/.claude/.auto-mode-active
   unset CLAUDE_AUTO_MODE
   ```
   Removing the sentinel is the entire revoke -- there is no settings file to
   restore.
3. Report the outcome and log path to the user. The existing Stop hook
   fires notify-send for AFK alerting; you don't need to.

## Hard rules

- **`sudo` always prompts**, even mid-run. Arbitrary root in an unattended loop
  is the one thing worth a human pause; the specific sudo commands you need are
  individually allow-listed already.
- **Never auto-merge.** Open PRs to `ready-for-review`, never `--auto-merge`.
- **Never run `nixos-rebuild switch/boot/test` or `nix-collect-garbage`.**
  These remain hard-denied via the `permissions.deny` list; a hook `allow`
  cannot override a deny.
- **Never `--no-verify` or `--force` on git.** The bash-guard hook blocks these
  regardless.
- **Stop conditions are real.** "Blocked" is a first-class exit, not a
  failure -- the user expects honest reporting over fake progress.
