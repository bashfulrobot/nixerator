# Cross-device Claude workflow

Three peer work hosts: `srv` (always-on), `qbert` (workstation, occasional direct-use), and `clanker` (always-on headless Claude VM). All run zellij and are reachable over SSH on the tailnet. Sessions live on the host where they were started; no cross-host state sync.

## Verbs

### `zj` / `czj` (canonical entry point)

The zellij module ships two wrappers, installed wherever `apps.cli.zellij.enable = true;` (i.e. on every host that adopts `archetypes.claudeWorkHost`, currently srv + qbert):

- `zj` — tight zellij wrapper. `zj s` list, `zj a [<name>]` attach, `zj n <name>` new (or `zj n <name> -- <cmd>`), `zj d` delete. Anything else passes through to `zellij`.
- `czj` — `zj` layered for Claude. Starts a zellij session whose first pane is `claude` with a remote-control endpoint already attached, so the same session is usable locally **and** from claude.ai/code without a separate control-tower service.

### bare `claude`

The claude-code module's fish wrapper (`modules/apps/cli/claude-code/cfg/fish.nix`) intercepts a bare `claude` invocation (no args, interactive TTY): it prompts for a session name, then runs `claude --bg --name "$name" --remote-control "$name"`. `--bg` and `--remote-control` combine on one invocation — the session is a background agent (manageable via `claude agents`/`claude attach <id>`) that *also* registers a Remote Control endpoint under the same name, so it shows up in claude.ai/code and the iOS app without a separate zellij launch. This works outside zellij too (any host, not just `archetypes.claudeWorkHost` peers).

### `work` (cross-host picker)

The `work` fish function is installed on every host (workstations + peers). Use it when you want to attach to a session that lives on another host without remembering which one.

- `work` — across-peer session picker (fzf if installed, numbered prompt otherwise).
- `work <name>` — attach locally if `<name>` exists locally; else fall back to a peer; else create on the current host.
- `work <name>@<host>` — force a specific host.
- `work --here <name>` — force the current host even if a peer has the name.
- `work --help` — usage.

Sessions are named per-repo by convention: zellij session name = repo basename (`nixerator`), with `<repo>#<N>` for `/github-issue` worktrees.

## iPhone

- **Spawn or resume from claude.ai/code:** czj sessions and bare-`claude` background sessions both register their own remote-control endpoints, so claude.ai/code's session list picks them up directly. No separate control-tower service.
- **SSH fallback (rarely needed):** Termius / Blink / Prompt over Tailscale → `ssh srv` (or `qbert` / `clanker`) → `zj a <name>` or `work`. SSH only — no mosh, no zellij-web.

## /github-issue

Auto-renames the zellij session to `<repo>#<N>` when invoked inside zellij. An issue kicked off from the iPhone is then discoverable from any other device via `work <repo>#<N>`. (The renaming itself lives in the skill at `~/.claude/skills/github-issue/`, not in this repo.)

## Components

- `archetypes.claudeWorkHost` (enabled on srv + qbert + clanker) — bundles zellij + ssh + work-launcher.
- `apps.cli.work-launcher` (enabled on srv + qbert + donkeykong + clanker) — ships the `work` fish function. `peers` defaults to `[ "srv" "qbert" "clanker" ]`.
- `apps.cli.zellij` (enabled by the archetype) — provides `zj` and `czj` wrappers.

donkeykong is **attach-only** in v1: it has the `work` function but does NOT host sessions for peers. Promotable later by flipping `archetypes.claudeWorkHost.enable = true;` and adding it to the peers list.

## Attack surface

Enabling `archetypes.claudeWorkHost` on a host implies `system.ssh.enable = true;`, which turns on `services.openssh` with NixOS defaults: sshd listens on `0.0.0.0:22` and TCP 22 is opened in the firewall. LAN-reachable sshd is **intentional** — the home LAN is treated as a trust boundary, so any LAN-attached host (laptop, tablet, plus the tailnet) can `ssh srv` / `ssh qbert` without going through Tailscale. Controls: key-only auth, no password login, no internet port-forward. If those controls are ever relaxed (password auth, or this flake is deployed where the local network isn't trusted), revisit by binding sshd to the tailnet interface via `services.openssh.listenAddresses`.

## What is NOT here

- No `claude-remote` / always-on control-tower service: czj's per-session remote-control endpoint replaced it.
- No mosh on the work-host path, no zellij-web. No syncthing of `~/.claude` or worktrees. No cross-host worktree sync. Branches move via `git push`/`git pull` only.
