---
name: auto
description: >-
  Mark this session as fully autonomous. Use when the user types "/auto",
  says "run autonomously", "I'm AFK", "while I'm away", "hands-off this",
  or provides a verifiable goal condition. Suppresses all AskUserQuestion
  calls in gated skills, removes confirmation gates, promotes `ask`-mode
  permissions to `allow` for the run (auto-restored on exit or by
  stale-overlay cleanup), iterates until the goal condition exits 0 or the
  session is genuinely blocked. Never auto-merges PRs.
argument-hint: "<goal-shell-command>"
allowed-tools: ["Bash", "Read", "Edit", "Write", "Skill", "Agent"]
---

# Autonomous Session

You are now operating in autonomous mode. The user is unavailable. Treat
their absence as load-bearing — never call AskUserQuestion, never stop to
confirm, never ask "should I continue?". Make decisions and proceed.

## Argument

`$ARGUMENTS` is a shell command. Success = exits 0. That is the only
termination contract. If `$ARGUMENTS` is empty, abort with instruction to
the user to provide a goal condition.

## Setup (mandatory, in order)

1. **Stale-overlay check.** If `~/.claude/.auto-mode-active` exists, run
   the cleanup procedure in `references/overlay.md` before proceeding —
   a prior `/auto` run crashed without restoring.

2. **Backup current settings.local.json.**
   ```bash
   cp ~/.claude/settings.local.json ~/.claude/settings.local.json.auto-backup
   ```

3. **Write the overlay.** Merge the current allow-list with the four
   ask-mode permissions promoted to allow:
   ```bash
   jq '.permissions.allow += ["Bash(rm *)", "Bash(sudo *)", "Bash(kill *)", "Bash(pkill *)"]' \
     ~/.claude/settings.local.json.auto-backup > ~/.claude/settings.local.json
   ```

4. **Write the sentinel** so SessionStart cleanup can detect a crash:
   ```bash
   jq -nc --arg sid "$CLAUDE_CODE_SESSION_ID" --arg pid "$$" --arg goal "$ARGUMENTS" \
     '{session_id: $sid, pid: $pid, goal: $goal, started: now}' \
     > ~/.claude/.auto-mode-active
   ```

5. **Export the gating env var.** Subprocesses and gated skills key off this:
   ```bash
   export CLAUDE_AUTO_MODE=1
   ```

6. **Create the run log:**
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

## Teardown (always run — success, blocked, or error)

1. Write final report to `$log` with: outcome, files touched, decisions made.
2. Restore settings:
   ```bash
   mv ~/.claude/settings.local.json.auto-backup ~/.claude/settings.local.json
   rm -f ~/.claude/.auto-mode-active
   unset CLAUDE_AUTO_MODE
   ```
3. Report the outcome and log path to the user. The existing Stop hook
   fires notify-send for AFK alerting; you don't need to.

## Hard rules

- **Never auto-merge.** Open PRs to `ready-for-review`, never `--auto-merge`.
- **Never run `nixos-rebuild switch/boot/test` or `nix-collect-garbage`.**
  These remain hard-denied via the existing `permissions.deny` list.
- **Never `--no-verify` or `--force` on git.** The existing bash-guard hook
  blocks these regardless.
- **Stop conditions are real.** "Blocked" is a first-class exit, not a
  failure — the user expects honest reporting over fake progress.
