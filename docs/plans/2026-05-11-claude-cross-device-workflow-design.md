# Claude Code cross-device workflow — design

Issue: none filed yet (workflow exploration, not a tracked feature). Suggested issue title: "Cross-device Claude Code workflow (peer hosts + work launcher)".

Suggested branch: `feat/claude-cross-device-workflow`.

## Background

Today the user runs Claude Code interactively from multiple devices (workstation, laptop-class workstation, iPhone) but lacks a consistent way to start a session on one machine and pick it back up from another. The friction shows up in three places:

1. **No naming convention** for zellij sessions, so "which session was I in?" requires either remembering or `zellij list-sessions` per host.
2. **No cross-host session discovery** — sessions started on `srv` are invisible from `qbert` and vice versa.
3. **iPhone story is partial.** `apps.cli.claude-remote.controlTower` is defined but not enabled on any host, and `zellij-web` (enabled on srv) is awkward to drive from iOS Safari.

The user's stated goal is **continuity, not always-on**: if a host is reachable, the user wants to attach back to whatever session they left there, from whichever device they're holding. Cross-device state *sync* is explicitly out of scope — the only "sync" allowed is git push/pull of working branches the user initiates intentionally.

Inventory of existing infrastructure relevant to this work:

| Component | Location | State today |
|---|---|---|
| Zellij + KDL config + cheatsheet keybind | `modules/apps/cli/zellij/default.nix` | Enabled on `srv` (`hosts/srv/modules.nix:78-94`) via terminal suite on workstations. Has `service.enable` (web), `mosh.enable`, `hideStatusBar`, `cheatsheet.enable` sub-options. |
| zellij-web behind Caddy tsnet | same module, `service.enable` branch | Enabled on `srv` only. To be retired by this design (see §6). |
| Claude remote-control "tower" | `modules/apps/cli/claude-remote/default.nix` | Module exists with `enable` + `controlTower.enable`; **not enabled on any host** (`grep` confirms). |
| SSH daemon | `modules/system/ssh/` | Enabled on `srv` (`hosts/srv/modules.nix:98`). Workstations enable it via the server archetype path / workstation defaults — needs verification per host during implementation. |
| Archetype pattern | `modules/archetypes/{server,workstation}/default.nix` | Two existing archetypes, both with a single `enable` option and a `config = lib.mkIf cfg.enable { … }` body that flips suites + system modules. |

Hosts in scope:

- `srv` — headless, always-on, primary Claude session host.
- `qbert` — workstation, occasionally used directly when the user is sitting at it. Symmetric peer to `srv`.
- `donkeykong` — workstation. Attach-only in v1 (no work-host role), can opt in later.

## Goals

1. **Single naming rule**: zellij session name = repo basename (`nixerator`), with `<repo>#<N>` for `/github-issue` worktrees. Derived from `pwd`, never typed.
2. **Peer-symmetric work hosts**: `srv` and `qbert` run identical Claude work infrastructure. Sessions live where they were started; no host is canonical.
3. **One `work` fish function** installed on every device. From the workstation, laptop, the work-hosts themselves, or an iPhone SSH client, the verb is the same and the result is "attach to the right session on the right host."
4. **iPhone via SSH only** — Termius / Blink / Prompt over Tailscale, then `work` inside the SSH session. No browser-based terminal in v1.
5. **iPhone spawn-new flow preserved**: claude.ai/code → control tower on `srv` or `qbert` → start a session in a chosen repo. Each peer registers a distinctly-named control tower so the picker is unambiguous.
6. **`/github-issue` auto-renames** its zellij session to `<repo>#<N>` when run inside zellij. Issues kicked off from the iPhone are immediately discoverable by name from the laptop the next morning.
7. **Zero state sync**. No syncthing of `~/.claude`, no auto-pulled branches, no rsync. The only state movement is `git push`/`git pull` the user runs intentionally.

## Non-goals

- **State or worktree sync across hosts.** Worktrees and `.claude/projects/` state live exclusively on the host that created them. Cost: a branch left uncommitted on one host is not visible from the other until the user commits + pushes + pulls. Accepted.
- **Cross-host session migration.** A session on `srv` cannot be "moved" to `qbert`; it lives until killed. To work the same task on the other host, the user starts a fresh session there.
- **Aggregator UI.** No web page or daemon that fans out `zellij list-sessions` across hosts. The `work` fish function does this in-process per invocation. Revisit only if friction is observed in practice.
- **Zellij-web survival.** Today srv has `apps.cli.zellij.service.enable = true` (browser-accessible zellij). This design retires it in favor of SSH-only iPhone access. The module option stays, just unused.
- **Mosh.** Today srv has `apps.cli.zellij.mosh.enable = true`. This design retires it. SSH-only.
- **Donkeykong as a work host (v1).** It can attach. It does not run a control tower or expose its zellij sessions to peers. Promotable later by flipping the archetype.

## Approach

Three artefacts:

1. **New archetype `archetypes.claudeWorkHost`** that bundles "this host is a Claude work peer": zellij (no web, no mosh), claude-remote + control tower, sshd, plus the `work-launcher` (configured to know about its peers). Enabled on `srv` and `qbert`.
2. **New module `apps.cli.work-launcher`** that ships the `work` fish function and the `peers` option. Installed everywhere — work-hosts use it the same way as attach-only hosts do (the function handles the local vs. remote branching internally).
3. **Small skill patch to `/github-issue`** that renames the zellij session when a worktree is created inside a zellij context.

Plus targeted edits:

- Move `users.users.${globals.user.name}.linger = true;` from the zellij `service.enable` branch into the claude-remote `controlTower.enable` branch (where it belongs — the user systemd service that actually needs linger).
- Per-host control tower naming: `claude-control-tower-${hostname}` instead of the unconditional `claude-control-tower`, so claude.ai/code's tower picker on iPhone shows distinct entries.
- Hosts: flip `archetypes.claudeWorkHost.enable = true;` on `srv` and `qbert`. Remove the now-redundant explicit `apps.cli.zellij.service.enable = true;` and `mosh.enable = true;` from `hosts/srv/modules.nix`. `donkeykong` gets `apps.cli.work-launcher.enable = true;` only.

## Detailed design

### File touches

| File | Change |
|---|---|
| `modules/archetypes/claudeWorkHost/default.nix` | **New.** Single `archetypes.claudeWorkHost.enable` option. Body flips `apps.cli.zellij.enable`, `apps.cli.zellij.hideStatusBar`, `apps.cli.zellij.cheatsheet.enable`, `apps.cli.claude-remote.enable`, `apps.cli.claude-remote.controlTower.enable`, `apps.cli.work-launcher.enable`, `system.ssh.enable`. Does NOT flip `apps.cli.zellij.service.enable` or `apps.cli.zellij.mosh.enable`. |
| `modules/apps/cli/work-launcher/default.nix` | **New.** Options: `enable`, `peers` (list of strings, default `[ "srv" "qbert" ]`), `sshUser` (string, defaults to `globals.user.name`). Installs the `work` fish function as `home-manager.users.<user>.programs.fish.functions.work`. |
| `modules/apps/cli/work-launcher/functions/work.fish` | **New.** Fish function source (see §"Launcher behavior" below). Read into the nix module via `builtins.readFile` and template-substituted for `@PEERS@` / `@SSH_USER@` / `@LOCAL_HOST@` placeholders. |
| `modules/apps/cli/claude-remote/default.nix` | (1) Rename the systemd service from `claude-control-tower` to `claude-control-tower-${config.networking.hostName}`. (2) Update `ExecStart`'s `--name` argument to match. (3) Add `users.users.${globals.user.name}.linger = true;` inside `lib.mkIf cfg.controlTower.enable`. |
| `modules/apps/cli/zellij/default.nix` | Remove `users.users.${globals.user.name}.linger = true;` from the `service.enable` branch. Leave the rest of the module alone (`service.enable`, `mosh.enable`, `tsnetNode`, `internalPort` stay as inert opt-in knobs). |
| `hosts/srv/modules.nix` | Replace the explicit `apps.cli.zellij = { enable; service.enable; tsnetNode; mosh.enable; hideStatusBar; cheatsheet.enable; … };` block with `archetypes.claudeWorkHost.enable = true;`. The archetype already sets `hideStatusBar` and `cheatsheet.enable`, so no override block is needed unless srv wants to diverge from the archetype default (it doesn't, in v1). |
| `hosts/srv/modules.nix` (imports list) | Add `../../modules/archetypes/claudeWorkHost` and `../../modules/apps/cli/work-launcher` to the explicit imports list (srv manually imports modules — `hosts/CLAUDE.md` is explicit about this). |
| `hosts/qbert/modules.nix` | Add `archetypes.claudeWorkHost.enable = true;`. No imports list change (workstations auto-import). |
| `hosts/donkeykong/modules.nix` | Add `apps.cli.work-launcher.enable = true;` (attach-only, no work-host role). |
| `~/.claude/skills/github-issue/SKILL.md` (or equivalent skill script) | Add a post-worktree-creation step: if `ZELLIJ` env var is set, run `zellij action rename-session "<repo>#<N>"`. **Out of nixerator's repo**; tracked separately, but referenced here so the workflow is end-to-end documented. |

### Archetype shape

```nix
# modules/archetypes/claudeWorkHost/default.nix
{ lib, config, ... }:

let
  cfg = config.archetypes.claudeWorkHost;
in
{
  options.archetypes.claudeWorkHost.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Enable the Claude work-host archetype: zellij (no web, no mosh),
      claude-remote with always-on control tower, sshd, and the work
      launcher. Sessions started on this host stay on this host and are
      attachable from any peer via the `work` fish function or directly
      via SSH + `zellij attach`.
    '';
  };

  config = lib.mkIf cfg.enable {
    apps.cli.zellij = {
      enable = true;
      hideStatusBar = true;
      cheatsheet.enable = true;
    };
    apps.cli.claude-remote = {
      enable = true;
      controlTower.enable = true;
    };
    apps.cli.work-launcher.enable = true;
    system.ssh.enable = true;
  };
}
```

Namespace matches `modules/CLAUDE.md` (`archetypes.*`). No `let cfg = config.NAMESPACE.PATH` body needed beyond the standard pattern.

### Launcher behavior

The `work` fish function lives at `modules/apps/cli/work-launcher/functions/work.fish` and is loaded as a fish function (not a script) so it shares the user's interactive environment.

Synopsis:

```
work                  # Show sessions across all peers, pick one, attach.
work <name>           # Resolve <name> across peers; attach (or create on
                      # current host if not found anywhere).
work <name>@<host>    # Force a specific host.
work --here <name>    # Force the current host even if a peer has the name.
```

"Current host" is detected at runtime via the `hostname` command and compared against the build-time `peers` list (passed in as a substituted constant). No drift between nix build state and runtime is expected — these are NixOS hosts where the hostname is set by configuration.

Resolution rules:

1. If `--here` is set OR a local session matches `<name>` (regardless of whether the current host is in `peers`): attach locally via `zellij attach -c <name>`.
2. Else for each `peer` in `peers` (excluding the current host): run `ssh -o ConnectTimeout=2 -o BatchMode=yes <sshUser>@<peer> zellij list-sessions 2>/dev/null`. If any peer returns a session named `<name>`, attach there with `ssh -t <sshUser>@<peer> -- zellij attach -c <name>`. First-match wins; the cross-host scan logs which peers were probed.
3. If nothing matched and the user invoked with a name: create a new session on the current host (`zellij attach -c <name>` auto-creates if missing).
4. If invoked with no name: build a unified list `(host, session)` across peers, present via `fzf` if available else a numbered prompt, attach to the choice.

Edge cases:

- **`work` called from inside a zellij session**: warn and exit non-zero; nesting zellij confuses keybinds. The cheatsheet documents `Ctrl-q` + `q` to detach first.
- **All peers unreachable**: fall back to local zellij with a warning.
- **SSH host-key prompt**: out of scope; the user's existing ssh module handles known_hosts (`modules/system/ssh/`). The launcher will fail loudly if a peer's key is unknown rather than silently auto-accepting.
- **`zellij list-sessions` exits 1 on no sessions**: treat as empty list, not error.

The function is intentionally a single fish file (~80 lines target). No background daemons, no cached state file. Each invocation is a fresh probe.

### Per-host control-tower naming

`modules/apps/cli/claude-remote/default.nix:123` currently registers the service as `systemd.user.services.claude-control-tower`. The remote-control server is invoked with `--name claude-control-tower` (line 133), which is what claude.ai/code displays. With control towers on two hosts (`srv`, `qbert`), the picker would show two ambiguously-named entries.

Change:

```nix
systemd.user.services."claude-control-tower-${config.networking.hostName}" = {
  # …
  Service.ExecStart = "${pkgs.llm-agents.claude-code}/bin/claude remote-control --name claude-control-tower-${config.networking.hostName} --permission-mode bypassPermissions";
  # …
};
```

The `towerDir` (`${globals.user.homeDirectory}/.local/share/claude-control-tower`) stays the same — it's a working directory, not a service identity.

### Linger relocation

Today:

```nix
# modules/apps/cli/zellij/default.nix:172-173
(lib.mkIf cfg.service.enable {
  users.users.${globals.user.name}.linger = true;
  # … caddy + tsnet + zellij-web …
})
```

This is the wrong owner for linger. The zellij-web *server* needs linger only because it's a `--user` systemd service. The same property is needed by the claude-remote `--user` service, which is unrelated to zellij. After this change, both srv and qbert get linger via the claude-remote module; if `service.enable` is ever flipped back on, it must not also set linger (otherwise a future module removal would leave a host without linger when another module silently relies on it).

Move it:

```nix
# modules/apps/cli/claude-remote/default.nix, inside lib.mkIf cfg.controlTower.enable
users.users.${globals.user.name}.linger = true;
```

Delete the line from the zellij module. The closure delta on hosts that have neither flag set is zero.

### iPhone integration

Two app categories, both already in the user's toolbox:

1. **SSH client** (Termius / Blink / Prompt) with Tailscale running on the phone: save two host entries (`srv`, `qbert`) using magicDNS; either save a "post-connect command" of `work` to land in the picker immediately, or save per-repo "snippets" like `work nixerator` for one-tap resume. No nixerator-side work required.
2. **claude.ai/code**: connect to `claude-control-tower-srv` and/or `claude-control-tower-qbert` to spawn new sessions in chosen repos. Tower naming is the only nixerator-side change needed for this flow.

### `/github-issue` skill change

In the skill's worktree-creation step, after `git worktree add` succeeds, detect zellij and rename:

```bash
if [ -n "${ZELLIJ:-}" ]; then
  zellij action rename-session "${repo_basename}#${issue_number}" || true
fi
```

This skill lives in `~/.claude/skills/`, not in this repo. Tracked as a separate follow-up in the implementation plan; called out here for end-to-end clarity.

## Rollout

Single PR is appropriate — the pieces are tightly coupled and the user is the only consumer.

1. Land the new `work-launcher` module + archetype on a feature branch.
2. Add archetype enable to `srv` and `qbert`; add launcher enable to `donkeykong`.
3. Edit zellij + claude-remote modules (linger relocation, control-tower naming).
4. `just qr` on each affected host in order: `donkeykong` first (lowest blast radius — just adds the fish function), then `qbert`, then `srv`. Confirm `zellij attach` + `work <name>` round-trip from each host to each peer before the next host.
5. Phone validation: Termius → srv → `work` → picker shows expected sessions. claude.ai/code shows `claude-control-tower-srv` and `claude-control-tower-qbert` as distinct entries.
6. Patch `/github-issue` skill separately; not blocking the nixerator PR.

Rollback plan: every change is a flip of an `enable` flag or a localised module diff. `git revert` of the PR plus `just qr` on each host restores the prior state. No data migration involved.

## Tradeoffs / accepted limitations

- **Network roaming kills the SSH transport.** Mosh would have auto-resumed; SSH does not. Cost: a tap to reconnect. The zellij session persists on the server, so no work is lost. Acceptable given iPhone-on-cellular mosh has historically been flaky.
- **No keystroke prediction.** SSH lacks mosh's local echo. On low-RTT Tailscale this is invisible; on high-latency cellular it would be noticeable, but the user has explicitly chosen SSH-only.
- **No aggregator UI.** The first-pass `work` function does an N-way SSH fan-out on every invocation (N = number of peers, currently 2). Per-invocation cost is ~50–200ms over the tailnet. Below the threshold where caching is worth the complexity. Revisit at N ≥ 4.
- **Donkeykong remains attach-only in v1.** Sessions started while sitting at donkeykong via local `zellij` are not discoverable from peers (the launcher won't probe a host that isn't in `peers`). User can promote donkeykong later by adding it to the archetype + the peers list.
- **`apps.cli.zellij.service.enable` and `.mosh.enable` retire to "inert option" status.** Module-cleanup churn (deleting the option entirely, removing Caddy vhost wiring) is intentionally deferred to keep this PR scoped to workflow ergonomics. If those branches are confirmed unused in 30 days, a follow-up PR removes them.
- **Single-user threat model.** Memory `project_threat_model.md` flags that "secret in `/nix/store`" findings get downgraded on these hosts. This design adds no new secret-storage surface — control-tower listens locally only, SSH is keypair-only via the existing ssh module — so the threat profile is unchanged.

## Open questions

1. **`workstation` archetype already enables `terminal.enable` and `ai.enable`.** Need to verify whether `terminal.enable` flips `apps.cli.zellij.enable` on workstations; if so, the `claudeWorkHost` archetype's `zellij.enable` is redundant on those hosts (idempotent in nix, but worth a one-line check during implementation).
2. **`apps.cli.work-launcher.peers` defaulting to `[ "srv" "qbert" ]`** is convenient but couples the module's default to a specific user's host list. Alternative: default to `[]` and require explicit host configuration. **Decision deferred to implementation review** — leaning toward the explicit-list default since this module is currently used only by one operator.
3. **`/github-issue` rename**: does the skill currently call any pre-existing zellij integration code? Verify before patching — there may already be a hook point.

## Spec ↔ later plan

A separate implementation plan (`docs/plans/2026-05-11-claude-cross-device-workflow.md`) will sequence the file touches, the per-host rebuild order, and verification steps.
