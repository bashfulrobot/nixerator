# Cross-device Claude workflow

Two peer work hosts: `srv` (always-on) and `qbert` (workstation, occasional direct-use). Both run `claude-control-tower-${hostname}` and zellij; both are reachable over SSH on the tailnet. Sessions live on the host where they were started; no cross-host state sync.

## Verbs

The `work` fish function is installed on every host (workstations + peers). It is the canonical entry point.

- `work` — across-peer session picker (fzf if installed, numbered prompt otherwise).
- `work <name>` — attach locally if `<name>` exists locally; else fall back to a peer; else create on the current host.
- `work <name>@<host>` — force a specific host.
- `work --here <name>` — force the current host even if a peer has the name.
- `work --help` — usage.

Sessions are named per-repo by convention: zellij session name = repo basename (`nixerator`), with `<repo>#<N>` for `/github-issue` worktrees.

## iPhone

- **Resume:** Termius / Blink / Prompt over Tailscale → `ssh srv` (or `qbert`) → `work`. SSH only — no mosh, no zellij-web.
- **Spawn new:** claude.ai/code → pick `claude-control-tower-srv` or `claude-control-tower-qbert` → start a new session in a repo.

## /github-issue

Auto-renames the zellij session to `<repo>#<N>` when invoked inside zellij. An issue kicked off from the iPhone is then discoverable from any other device via `work <repo>#<N>`. (The renaming itself lives in the skill at `~/.claude/skills/github-issue/`, not in this repo.)

## Components

- `archetypes.claudeWorkHost` (enabled on srv + qbert) — bundles zellij + claude-remote + control tower + ssh + work-launcher.
- `apps.cli.work-launcher` (enabled on srv + qbert + donkeykong) — ships the `work` fish function. `peers` defaults to `[ "srv" "qbert" ]`.
- `apps.cli.claude-remote.controlTower` — the systemd `--user` service (per-host name `claude-control-tower-${hostname}`) that claude.ai/code connects to.

donkeykong is **attach-only** in v1: it has the `work` function but does NOT run a control tower or expose sessions to peers. Promotable later by flipping `archetypes.claudeWorkHost.enable = true;` and adding it to the peers list.

## What is NOT here

- No mosh. No zellij-web. No syncthing of `~/.claude` or worktrees. No cross-host worktree sync. Branches move via `git push`/`git pull` only.
