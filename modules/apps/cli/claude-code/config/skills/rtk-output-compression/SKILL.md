---
name: rtk-output-compression
description: >-
  How the `rtk` output-compression wrapper rewrites Bash commands, what it
  filters out, how to bypass it, and why its tee logs are guarded.
when_to_use: >-
  Read when Bash output looks truncated, filtered, reordered, or otherwise
  unlike the raw tool output; when git, gh, kubectl, or docker returns something
  surprising or suspiciously short; when RTK_DISABLED, `rtk gain`, `rtk proxy`,
  `rtk discover`, or exclude_commands come up; when a wrapped command failed and
  you are about to read its tee log under `~/.local/share/rtk/tee/`; or before
  concluding a tool is broken when it may only be filtered.
effort: low
allowed-tools: ["Bash", "Read"]
---

# rtk (output compression)

`rtk` wraps common dev commands and compresses their output before it reaches
my context. A `PreToolUse` hook rewrites eligible Bash commands automatically,
so most of the time there is nothing to do.

- `RTK_DISABLED=1 <cmd>` runs one command unwrapped. Reach for this when a
  filter has clearly eaten something you need, not as a default.
- `rtk proxy <cmd>` runs a command unfiltered but still counts it in rtk's
  usage tracking. It does not compress anything.
- `rtk gain` reports how many tokens the filters actually saved; `rtk gain
  --graph` plots daily savings.
- `rtk discover` scans past Claude Code history for commands that could have
  been wrapped but were not.
- The 1Password recipes (`just rs`, `just ps`, `just cs`, and friends) are
  listed in rtk's `exclude_commands`, so they can never be wrapped even if a
  later rtk learns to wrap `just`. That list lives in nixerator's
  `modules/apps/cli/claude-code` module.
- `exclude_commands` governs only the automatic hook. Calling `rtk` yourself
  (`rtk just <recipe>`, `rtk proxy <cmd>`, `rtk read <path>`) skips the
  exclusion list entirely.
- A failed wrapped command leaves its unfiltered output in
  `~/.local/share/rtk/tee/`. The secret guard denies reading those logs,
  because they can hold rendered secrets. Re-running the command without rtk
  is fine only when you already know its output carries no credentials, and
  rtk wraps `kubectl`, `docker`, `git` and `gh`, so plenty of them do.
  Otherwise narrow the command to the specific field you need rather than
  dumping the whole thing.
