---
name: agentos-init
description: |
  Install Agent OS (buildermethods/agent-os) into the current project
  directory by invoking the upstream project-install.sh. Use when the
  user says "install agent-os", "init agent-os here", "set up Agent OS
  in this project", or "/agentos-init". Creates agent-os/standards/ and
  .claude/commands/agent-os/ in the project via the native installer
  shipped with the Nix-pinned Agent OS base installation at ~/agent-os/.
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

# agentos-init

Install Agent OS into the current project by running the upstream
`project-install.sh` that ships with the Nix-managed base install at
`~/agent-os/`.

## When to use

- User asks to "init agent-os", "install agent-os here", "set up agent-os"
- User invokes `/agentos-init`
- A new project needs Agent OS standards and Claude Code commands wired up

## What it does

Runs `agent-os-project-install` (the wrapper installed on PATH by the
Nixerator `apps.cli.agentos` module). The wrapper invokes
`$HOME/agent-os/scripts/project-install.sh` against the current working
directory. That upstream script creates:

- `./agent-os/standards/` -- project coding standards (copied from the
  selected profile under `~/agent-os/profiles/<profile>/standards/`)
- `./agent-os/standards/index.yml` -- standard matching index
- `./.claude/commands/agent-os/` -- Agent OS slash commands for Claude Code

## How to use

1. Confirm the current working directory is the project root the user
   wants to install Agent OS into. If uncertain, ask.
2. Check whether `~/agent-os/` is populated. If missing, the user's NixOS
   rebuild has not run since the `apps.cli.agentos` module was enabled.
   Report this clearly and stop -- do not try to bootstrap it manually.
3. Check for existing `./agent-os/` in the project. If present, ask the
   user whether to overwrite, preserve standards (`--commands-only`), or
   abort.
4. Optionally ask which profile to use. Default is the `default` profile
   (set in `~/agent-os/config.yml`). Other upstream profiles the user may
   have added live under `~/agent-os/profiles/`.
5. Invoke the installer:

   ```bash
   agent-os-project-install [--profile <name>] [--commands-only]
   ```

6. After it completes, summarize what was created and suggest the user
   review `./agent-os/standards/` and adjust as needed for the project.

## Flags

- `--profile <name>` -- install a non-default profile
- `--commands-only` -- update only `.claude/commands/agent-os/`, leave
  existing `./agent-os/standards/` untouched

## Safety

- Never run outside the project root the user intends to install into.
- `project-install.sh` writes only to the current directory; it never
  modifies `~/agent-os/` or anything outside the project.
- If Agent OS base is not installed at `~/agent-os/`, fail with a clear
  message pointing at the Nix module. Do not attempt to install Agent OS
  itself -- that is Nix's job.
