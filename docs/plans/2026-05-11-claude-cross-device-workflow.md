# Claude Code cross-device workflow — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up the peer-host Claude workflow: a new `claudeWorkHost` archetype + `work-launcher` module enabling identical infrastructure on `srv` and `qbert`, a `work` fish function for cross-host session attach via SSH only, per-host control-tower naming so claude.ai/code's picker is unambiguous, retirement of zellij-web + mosh, and a `donkeykong` attach-only install.

**Architecture:** Three new files (`modules/archetypes/claudeWorkHost/default.nix`, `modules/apps/cli/work-launcher/default.nix`, embedded `work.fish` body) + four surgical edits (`modules/apps/cli/claude-remote/default.nix` for service rename + linger, `modules/apps/cli/zellij/default.nix` for linger removal, `modules/suites/terminal/default.nix` to drop mosh, three host files to flip enables). Auto-import on workstations means `qbert` / `donkeykong` need no `imports = …` change; `srv` does (it manually imports per `hosts/CLAUDE.md`).

**Tech Stack:** Nix, Home Manager, NixOS, fish shell, systemd (user services), zellij, OpenSSH, just (justfile runner). Project conventions: `just qr` per host for rebuild (writes log to `/tmp/nixerator-rebuild.log`); `nix fmt` for formatting; `statix` + `deadnix` for lint. **Never run `git commit` or `git push` — the user handles commits.** After each task, the plan emits a *suggested* conventional commit message; do not execute it.

**Spec:** [`docs/plans/2026-05-11-claude-cross-device-workflow-design.md`](./2026-05-11-claude-cross-device-workflow-design.md). Read it for the design rationale.

**Branch:** `feat/claude-cross-device-workflow` (base off `main` — local `main` is kept fresh by the session-start git-sync hook).

**Rebuild order at the end:** `donkeykong` → `qbert` → `srv` (ascending blast radius). Each host's `just qr` is run by the user; the plan documents what each rebuild should produce.

---

### Task 1: Create the `work-launcher` module skeleton

Empty-body module so it auto-imports cleanly and `apps.cli.work-launcher.enable` becomes a flippable option before the fish function lands in Task 2.

**Files:**

- Create: `modules/apps/cli/work-launcher/default.nix`

- [ ] **Step 1: Create the module file**

```nix
{
  lib,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.cli.work-launcher;
in
{
  options.apps.cli.work-launcher = {
    enable = lib.mkEnableOption "work fish function for cross-host zellij session attach";

    peers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "srv"
        "qbert"
      ];
      description = ''
        Hostnames the `work` fish function probes for zellij sessions
        when resolving an unqualified `work <name>` invocation, and when
        building the no-argument picker. The current host (matched at
        runtime via the `hostname` command) is automatically skipped on
        the SSH leg — local sessions are listed via `zellij list-sessions`
        directly.
      '';
    };

    sshUser = lib.mkOption {
      type = lib.types.str;
      default = globals.user.name;
      description = ''
        SSH user the launcher connects to peers as. Defaults to
        globals.user.name (single-user hosts under this flake).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Fish function body added in Task 2.
  };
}
```

- [ ] **Step 2: Format**

Run:

```bash
nix fmt modules/apps/cli/work-launcher/default.nix
```

Expected: no errors, file may be reformatted.

- [ ] **Step 3: Lint**

Run:

```bash
statix check modules/apps/cli/work-launcher/default.nix
deadnix --fail modules/apps/cli/work-launcher/default.nix
```

Expected: both exit 0 (no warnings — file is small and self-consistent).

- [ ] **Step 4: Verify auto-import sees the new module**

Run:

```bash
nix flake check --no-build 2>&1 | head -50
```

Expected: no errors related to `apps.cli.work-launcher`. The option `apps.cli.work-launcher.enable` should now exist in the module tree, but no host has flipped it yet, so configuration evaluation is a no-op.

- [ ] **Step 5: Suggested commit**

```
feat(work-launcher): scaffold module with peers + sshUser options

Empty-body module that exposes apps.cli.work-launcher.{enable,peers,sshUser}.
Body (fish function) lands in the next commit. peers defaults to
[srv qbert] to match the two work-host peers; sshUser defaults to
globals.user.name.
```

---

### Task 2: Add the `work` fish function

Inline the function body via `programs.fish.functions.work` so it ships through home-manager and gets the user's normal fish environment.

**Files:**

- Modify: `modules/apps/cli/work-launcher/default.nix`

- [ ] **Step 1: Replace the `config = lib.mkIf cfg.enable { … };` block with the version below**

The full module file should now read:

```nix
{
  lib,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.cli.work-launcher;

  # Render peers as a space-separated, double-quoted fish list literal so
  # the function body can do `set -l peers $peersList` without further
  # parsing. Hostnames don't contain spaces, but quoting is cheap insurance.
  peersFishList = lib.concatMapStringsSep " " (p: ''"${p}"'') cfg.peers;
in
{
  options.apps.cli.work-launcher = {
    enable = lib.mkEnableOption "work fish function for cross-host zellij session attach";

    peers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "srv"
        "qbert"
      ];
      description = ''
        Hostnames the `work` fish function probes for zellij sessions
        when resolving an unqualified `work <name>` invocation, and when
        building the no-argument picker. The current host (matched at
        runtime via the `hostname` command) is automatically skipped on
        the SSH leg — local sessions are listed via `zellij list-sessions`
        directly.
      '';
    };

    sshUser = lib.mkOption {
      type = lib.types.str;
      default = globals.user.name;
      description = ''
        SSH user the launcher connects to peers as. Defaults to
        globals.user.name (single-user hosts under this flake).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      programs.fish.functions.work = {
        description = "Attach to (or create) a zellij session across peer hosts";
        body = ''
          # Build-time configuration injected by the work-launcher module.
          set -l peers ${peersFishList}
          set -l ssh_user ${cfg.sshUser}
          set -l current_host (hostname)

          # --- arg parsing ---
          set -l force_local 0
          set -l name ""
          for arg in $argv
              switch $arg
                  case '--here'
                      set force_local 1
                  case '-h' '--help'
                      echo "Usage: work [--here] [<name>[@<host>]]"
                      echo ""
                      echo "  work                  pick a session across peers, attach"
                      echo "  work <name>           attach to <name>; create on current host if not found"
                      echo "  work <name>@<host>    attach to <name> on specific <host>"
                      echo "  work --here <name>    force current host"
                      return 0
                  case '*'
                      set name $arg
              end
          end

          # Refuse to nest zellij.
          if set -q ZELLIJ
              echo "work: already inside a zellij session. Detach first (Ctrl-q q)." >&2
              return 2
          end

          # Explicit <name>@<host> form short-circuits discovery.
          if string match -q '*@*' -- $name
              set -l parts (string split -m1 '@' -- $name)
              set name $parts[1]
              set -l target $parts[2]
              if test "$target" = "$current_host"
                  zellij attach -c $name
                  return $status
              end
              ssh -t -o ConnectTimeout=2 $ssh_user@$target -- zellij attach -c $name
              return $status
          end

          # --here forces local even if a peer has the name.
          if test $force_local -eq 1
              if test -z "$name"
                  echo "work --here requires a <name>" >&2
                  return 2
              end
              zellij attach -c $name
              return $status
          end

          # Local sessions snapshot.
          set -l local_sessions
          if type -q zellij
              set local_sessions (zellij list-sessions -s 2>/dev/null | string trim)
          end

          # If a name was given and exists locally, attach immediately.
          if test -n "$name"
              if contains -- $name $local_sessions
                  zellij attach -c $name
                  return $status
              end
          end

          # Probe peers (skip current host).
          set -l inventory_hosts
          set -l inventory_sessions
          for s in $local_sessions
              set inventory_hosts $inventory_hosts $current_host
              set inventory_sessions $inventory_sessions $s
          end
          for peer in $peers
              if test "$peer" = "$current_host"
                  continue
              end
              set -l remote (ssh -o ConnectTimeout=2 -o BatchMode=yes $ssh_user@$peer zellij list-sessions -s 2>/dev/null | string trim)
              for s in $remote
                  set inventory_hosts $inventory_hosts $peer
                  set inventory_sessions $inventory_sessions $s
              end
          end

          # Name given: find first peer match.
          if test -n "$name"
              for i in (seq (count $inventory_sessions))
                  if test "$inventory_sessions[$i]" = "$name"
                      set -l target $inventory_hosts[$i]
                      if test "$target" = "$current_host"
                          zellij attach -c $name
                      else
                          ssh -t -o ConnectTimeout=2 $ssh_user@$target -- zellij attach -c $name
                      end
                      return $status
                  end
              end
              echo "work: no session '$name' found across peers ($peers), creating on $current_host" >&2
              zellij attach -c $name
              return $status
          end

          # No name: present picker.
          set -l n (count $inventory_sessions)
          if test $n -eq 0
              echo "work: no zellij sessions found on any peer ($peers)" >&2
              return 1
          end

          set -l choices
          for i in (seq $n)
              set choices $choices "$inventory_sessions[$i]  ($inventory_hosts[$i])"
          end

          set -l picked_idx
          if type -q fzf
              set -l picked (printf '%s\n' $choices | fzf --prompt="session> " --height=40%)
              if test -z "$picked"
                  return 130
              end
              for i in (seq $n)
                  if test "$choices[$i]" = "$picked"
                      set picked_idx $i
                      break
                  end
              end
          else
              for i in (seq $n)
                  echo "$i) $choices[$i]"
              end
              read -P "Pick #: " idx
              if not string match -qr '^[0-9]+$' -- $idx
                  return 130
              end
              if test $idx -lt 1 -o $idx -gt $n
                  return 130
              end
              set picked_idx $idx
          end

          set -l picked_session $inventory_sessions[$picked_idx]
          set -l picked_host $inventory_hosts[$picked_idx]
          if test "$picked_host" = "$current_host"
              zellij attach -c $picked_session
          else
              ssh -t -o ConnectTimeout=2 $ssh_user@$picked_host -- zellij attach -c $picked_session
          end
          return $status
        '';
      };
    };
  };
}
```

- [ ] **Step 2: Format**

```bash
nix fmt modules/apps/cli/work-launcher/default.nix
```

Expected: clean, possibly reformatted.

- [ ] **Step 3: Lint**

```bash
statix check modules/apps/cli/work-launcher/default.nix
deadnix --fail modules/apps/cli/work-launcher/default.nix
```

Expected: exit 0 on both.

- [ ] **Step 4: Evaluate the module without building**

Run:

```bash
nix eval --raw .#nixosConfigurations.donkeykong.config.system.build.toplevel.drvPath 2>&1 | tail -5
```

Expected: a `/nix/store/…drv` path (drv evaluation succeeds). If you get an evaluation error, fix and re-run. **Do not** `nix build` — that's the justfile's job.

- [ ] **Step 5: Suggested commit**

```
feat(work-launcher): add `work` fish function

Implements peer-aware session resolution:
- `work <name>` attaches locally, falls back to a peer, creates locally
  if nowhere
- `work <name>@<host>` forces a target
- `work --here <name>` forces local
- No-arg invocation builds an across-peer picker (fzf if present,
  numbered prompt otherwise)
Uses SSH only — no mosh.
```

---

### Task 3: Create the `claudeWorkHost` archetype

**Files:**

- Create: `modules/archetypes/claudeWorkHost/default.nix`

- [ ] **Step 1: Create the archetype file**

```nix
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

- [ ] **Step 2: Format**

```bash
nix fmt modules/archetypes/claudeWorkHost/default.nix
```

- [ ] **Step 3: Lint**

```bash
statix check modules/archetypes/claudeWorkHost/default.nix
deadnix --fail modules/archetypes/claudeWorkHost/default.nix
```

Expected: exit 0 on both.

- [ ] **Step 4: Evaluation check**

```bash
nix eval --raw .#nixosConfigurations.qbert.config.system.build.toplevel.drvPath 2>&1 | tail -5
```

Expected: drv path. The option `archetypes.claudeWorkHost.enable` should now exist; no host has flipped it yet.

- [ ] **Step 5: Suggested commit**

```
feat(archetypes): add claudeWorkHost archetype

Bundles the "host runs Claude sessions you might want to attach to from
elsewhere" role: zellij (no web, no mosh), claude-remote + controlTower,
ssh, work-launcher. Enabled per host in subsequent commits.
```

---

### Task 4: Rename control-tower service per-host + relocate linger

Two coupled edits to `claude-remote/default.nix`: (1) include hostname in the systemd unit name and the `--name` argument passed to `claude remote-control`, so claude.ai/code's tower picker on iPhone shows distinct entries per host; (2) move `linger = true` here from the zellij module — linger is needed for the `--user` systemd unit to survive logout, and the claude-remote control tower is the unit that actually needs it.

**Files:**

- Modify: `modules/apps/cli/claude-remote/default.nix`

- [ ] **Step 1: Add hostname to the systemd unit name and ExecStart**

Open `modules/apps/cli/claude-remote/default.nix`. The current `controlTower.enable` branch defines `systemd.user.services.claude-control-tower` (line 123) and `ExecStart = "${pkgs.llm-agents.claude-code}/bin/claude remote-control --name claude-control-tower --permission-mode bypassPermissions";` (line 133).

Replace those two references. The replacement uses `config.networking.hostName`:

```nix
        systemd.user.services."claude-control-tower-${config.networking.hostName}" = {
          Unit = {
            Description = "Claude Code control tower (always-on remote-control server)";
            After = [ "graphical-session.target" ];
          };
          Service = {
            Type = "simple";
            WorkingDirectory = towerDir;
            ExecStart = "${pkgs.llm-agents.claude-code}/bin/claude remote-control --name claude-control-tower-${config.networking.hostName} --permission-mode bypassPermissions";
            UnsetEnvironment = "CLAUDE_CODE_REMOTE CLAUDE_CODE_REMOTE_SESSION_ID CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_CONTAINER_ID CLAUDECODE";
            Restart = "always";
            RestartSec = 5;
            StandardInput = "null";
            StandardOutput = "journal";
            StandardError = "journal";
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
        };
```

- [ ] **Step 2: Add linger inside the controlTower branch**

Inside the same `lib.mkIf cfg.controlTower.enable` block, **above** `home-manager.users.${globals.user.name}`, add:

```nix
      users.users.${globals.user.name}.linger = true;
```

So the block opens like this:

```nix
    (lib.mkIf cfg.controlTower.enable {
      assertions = [
        {
          assertion = cfg.enable;
          message = "apps.cli.claude-remote.controlTower.enable requires apps.cli.claude-remote.enable = true.";
        }
      ];

      users.users.${globals.user.name}.linger = true;

      home-manager.users.${globals.user.name} = {
        # … existing body …
      };
    })
```

- [ ] **Step 3: Format**

```bash
nix fmt modules/apps/cli/claude-remote/default.nix
```

- [ ] **Step 4: Lint**

```bash
statix check modules/apps/cli/claude-remote/default.nix
deadnix --fail modules/apps/cli/claude-remote/default.nix
```

Expected: exit 0 on both.

- [ ] **Step 5: Evaluation check**

```bash
nix eval --raw .#nixosConfigurations.qbert.config.system.build.toplevel.drvPath 2>&1 | tail -5
```

Expected: drv path (no evaluation errors). On hosts where controlTower is still disabled, this branch is dead and the diff is a no-op.

- [ ] **Step 6: Suggested commit**

```
refactor(claude-remote): hostname-scoped tower service + own linger

Rename the systemd user service from `claude-control-tower` to
`claude-control-tower-${hostname}` and pass the same value via --name so
claude.ai/code's tower picker shows distinct entries when multiple work
hosts are online. Move `linger = true` here from the zellij service.enable
branch — the user systemd unit that needs linger is the control tower,
not zellij-web.
```

---

### Task 5: Remove linger from the zellij `service.enable` branch

Counterpart to Task 4. Today the zellij module sets `users.users.<user>.linger = true;` inside `lib.mkIf cfg.service.enable`. That ownership is wrong; remove it. The line lives at `modules/apps/cli/zellij/default.nix:172-173`.

**Files:**

- Modify: `modules/apps/cli/zellij/default.nix`

- [ ] **Step 1: Locate and delete the linger lines**

Open `modules/apps/cli/zellij/default.nix`. Inside the `lib.mkIf cfg.service.enable` branch, find:

```nix
        # Required so the user's systemd manager (and therefore the
        # zellij-web user service) starts at boot on headless hosts.
        # Without linger, systemd --user only spawns when the user
        # actively logs in, defeating the "browser-accessible without
        # SSH" promise of the web client.
        users.users.${globals.user.name}.linger = true;
```

Delete both the comment block and the `users.users.…linger` line. Leave the rest of the `service.enable` body untouched.

- [ ] **Step 2: Format**

```bash
nix fmt modules/apps/cli/zellij/default.nix
```

- [ ] **Step 3: Lint**

```bash
statix check modules/apps/cli/zellij/default.nix
deadnix --fail modules/apps/cli/zellij/default.nix
```

Expected: exit 0. If `deadnix` flags `globals` as unused inside that branch (because the only consumer was the linger line), check whether `globals` is still referenced elsewhere in the file before deleting any import. Likely it is — the home-manager users block references `globals.user.name` elsewhere.

- [ ] **Step 4: Evaluation check**

```bash
nix eval --raw .#nixosConfigurations.srv.config.system.build.toplevel.drvPath 2>&1 | tail -5
```

Expected: drv path. On srv, where `service.enable = true` is still set today, the diff removes one attribute from the system config — which is fine because we're about to retire `service.enable` on srv in Task 7.

- [ ] **Step 5: Suggested commit**

```
refactor(zellij): drop linger from service.enable branch

linger ownership moves to claude-remote.controlTower.enable (see prior
commit). Keeping it here would mean: (a) double-declaration when both
toggles are on, and (b) silent breakage if a future host enabled only
controlTower with no zellij-web.
```

---

### Task 6: Drop mosh from the terminal suite

`modules/suites/terminal/default.nix:32` sets `apps.cli.zellij.mosh.enable = true;`, which affects every workstation (`donkeykong`, `qbert`). With SSH-only iPhone access, mosh is dead weight. Removing the line closes the UDP 60000–61000 firewall range on those hosts.

Per `modules/suites/CLAUDE.md`: "Changes to a suite affect ALL hosts whose archetype enables it — check `archetypes/` to understand blast radius before modifying." Blast radius: all workstations (`archetypes.workstation` → `suites.terminal.enable = true`).

**Files:**

- Modify: `modules/suites/terminal/default.nix`

- [ ] **Step 1: Remove the `mosh.enable` line**

In the file, find the zellij block:

```nix
      zellij = {
        enable = true;
        mosh.enable = true;
        hideStatusBar = true;
        cheatsheet.enable = true;
      };
```

Remove the `mosh.enable = true;` line. The block becomes:

```nix
      zellij = {
        enable = true;
        hideStatusBar = true;
        cheatsheet.enable = true;
      };
```

- [ ] **Step 2: Format**

```bash
nix fmt modules/suites/terminal/default.nix
```

- [ ] **Step 3: Lint**

```bash
statix check modules/suites/terminal/default.nix
deadnix --fail modules/suites/terminal/default.nix
```

Expected: exit 0 on both.

- [ ] **Step 4: Evaluation check on a workstation**

```bash
nix eval --raw .#nixosConfigurations.qbert.config.system.build.toplevel.drvPath 2>&1 | tail -5
nix eval --raw .#nixosConfigurations.donkeykong.config.system.build.toplevel.drvPath 2>&1 | tail -5
```

Expected: both produce drv paths. The diff at activation time will remove `pkgs.mosh` from `environment.systemPackages` and close UDP 60000–61000 on workstations.

- [ ] **Step 5: Suggested commit**

```
refactor(terminal): drop mosh from the terminal suite

The cross-device workflow is SSH-only. mosh is no longer used on
workstations; removing it closes UDP 60000-61000 on the firewall and
shrinks the closure by one package. The mosh.enable option in the
zellij module stays as an inert opt-in for any future host that wants
it back.
```

---

### Task 7: Enable archetype on srv (and retire zellij-web + mosh + direct enables)

srv manually imports modules in `hosts/srv/modules.nix` (per `hosts/CLAUDE.md`). Adding the archetype requires both the imports list update AND the enable flag. The existing explicit `apps.cli.zellij = { … }` block goes away — the archetype now owns that surface.

**Files:**

- Modify: `hosts/srv/modules.nix`

- [ ] **Step 1: Update the imports list**

Open `hosts/srv/modules.nix`. Find the explicit imports list — `../../modules/apps/cli/zellij` is at line 24 (per earlier grep). Add two new lines for the archetype and the work-launcher:

```nix
    ../../modules/archetypes/claudeWorkHost
    ../../modules/apps/cli/zellij
    ../../modules/apps/cli/work-launcher
    ../../modules/apps/cli/claude-remote
```

`claude-remote` may or may not already be in the imports list — if absent, add it (the archetype turns it on, so the module must be present). Keep the rest of the imports untouched.

- [ ] **Step 2: Replace the explicit zellij block with the archetype enable**

In the same file, find the explicit `apps.cli.zellij = { … };` block (lines ~78–94: `enable = true;`, `service.enable = true;`, `tsnetNode = "zellij";`, `mosh.enable = true;`, `hideStatusBar = true;`, `cheatsheet.enable = true;`).

Replace the whole block with:

```nix
    archetypes.claudeWorkHost.enable = true;
```

(The archetype handles `enable`, `hideStatusBar`, `cheatsheet.enable`. `service.enable`, `tsnetNode`, `mosh.enable` are intentionally retired on srv.)

- [ ] **Step 3: Format**

```bash
nix fmt hosts/srv/modules.nix
```

- [ ] **Step 4: Lint**

```bash
statix check hosts/srv/modules.nix
deadnix --fail hosts/srv/modules.nix
```

Expected: exit 0.

- [ ] **Step 5: Evaluation check**

```bash
nix eval --raw .#nixosConfigurations.srv.config.system.build.toplevel.drvPath 2>&1 | tail -5
```

Expected: drv path. If `system.caddy.enable` was previously implied only by the zellij service.enable branch, srv's caddy config may now be unused — that's expected; `system.caddy.enable` will simply not be set by this change, and other srv vhosts (if any) still drive it. If srv had **only** the zellij vhost on Caddy and you want to drop Caddy entirely, that's a follow-up out of scope for this plan.

- [ ] **Step 6: Suggested commit**

```
feat(srv): adopt claudeWorkHost archetype, retire zellij-web + mosh

srv now enables apps.cli.zellij (no web, no mosh), apps.cli.claude-remote
with controlTower, system.ssh, and apps.cli.work-launcher via the new
archetype. The explicit per-option block is removed; the tsnet vhost is
intentionally dropped (iPhone moves to SSH-only via Termius/Blink).
```

---

### Task 8: Enable archetype on qbert

Workstations auto-import modules; no `imports = …` change needed. qbert is the second work-host peer; flipping the archetype turns on the control tower (and gives the host a `claude-control-tower-qbert` systemd unit).

**Files:**

- Modify: `hosts/qbert/modules.nix`

- [ ] **Step 1: Add the archetype enable**

Open `hosts/qbert/modules.nix`. Add to the top-level attribute set (anywhere is fine, but conventionally near other archetype/suite enables — qbert doesn't currently set any archetype directly in this file; the workstation archetype is set in `hosts/qbert/configuration.nix`):

```nix
  archetypes.claudeWorkHost.enable = true;
```

- [ ] **Step 2: Format**

```bash
nix fmt hosts/qbert/modules.nix
```

- [ ] **Step 3: Lint**

```bash
statix check hosts/qbert/modules.nix
deadnix --fail hosts/qbert/modules.nix
```

Expected: exit 0.

- [ ] **Step 4: Evaluation check**

```bash
nix eval --raw .#nixosConfigurations.qbert.config.system.build.toplevel.drvPath 2>&1 | tail -5
```

Expected: drv path. The diff at activation will add: the claude-control-tower-qbert systemd user service, linger on the user, sshd if not already enabled by the workstation archetype, and the `work` fish function.

- [ ] **Step 5: Suggested commit**

```
feat(qbert): adopt claudeWorkHost archetype

Symmetric peer to srv. Adds claude-control-tower-qbert systemd user
service, work-launcher fish function, sshd, linger. Workstation
archetype was already providing zellij via the terminal suite; the
archetype now also explicitly enables zellij with the same defaults
(idempotent in nix).
```

---

### Task 9: Install `work-launcher` on donkeykong (attach-only)

donkeykong does not run a control tower or expose its sessions to peers in v1. It just gets the fish function so the user can attach back to srv/qbert from a donkeykong shell.

**Files:**

- Modify: `hosts/donkeykong/modules.nix`

- [ ] **Step 1: Add the work-launcher enable**

Open `hosts/donkeykong/modules.nix`. Add to the top-level attribute set:

```nix
  apps.cli.work-launcher.enable = true;
```

- [ ] **Step 2: Format**

```bash
nix fmt hosts/donkeykong/modules.nix
```

- [ ] **Step 3: Lint**

```bash
statix check hosts/donkeykong/modules.nix
deadnix --fail hosts/donkeykong/modules.nix
```

Expected: exit 0.

- [ ] **Step 4: Evaluation check**

```bash
nix eval --raw .#nixosConfigurations.donkeykong.config.system.build.toplevel.drvPath 2>&1 | tail -5
```

Expected: drv path. Activation will add the `work` fish function only (no control tower, no archetype side effects).

- [ ] **Step 5: Suggested commit**

```
feat(donkeykong): install work-launcher (attach-only)

Adds the `work` fish function on donkeykong so the user can attach to
sessions on srv or qbert from a donkeykong shell. donkeykong does not
run a control tower in v1; promoting it to a work-host peer is a
one-flag change later.
```

---

### Task 10: Rebuild donkeykong and smoke-test the function

donkeykong has the lowest blast radius — fish-function-only — so rebuild it first to catch any module evaluation or fish-syntax mistake before touching the work hosts.

**Files:** (no source changes, this is a verification task)

- [ ] **Step 1: User runs the rebuild**

Tell the user:

> Run `just qr` on donkeykong. The output is captured to `/tmp/nixerator-rebuild.log`. If it fails, spawn the `nix` subagent on the log per the project convention (`.claude/docs/conventions.md`) — do **not** read the log inline.

Expected: rebuild completes; `Restart` count on user systemd services may bump if any restarted.

- [ ] **Step 2: User verifies the function loads**

In a fresh fish shell on donkeykong:

```fish
type -a work
```

Expected: prints `work is a function with definition` followed by the body.

- [ ] **Step 3: User runs `work --help`**

```fish
work --help
```

Expected: usage block — four lines starting with `Usage: work [--here]…`.

- [ ] **Step 4: No commit**

Verification only.

---

### Task 11: Rebuild qbert and verify the control tower

qbert is next. After `just qr`, the new systemd user service `claude-control-tower-qbert.service` should be active.

**Files:** (verification only)

- [ ] **Step 1: User runs the rebuild**

> Run `just qr` on qbert. On failure, spawn the nix subagent on `/tmp/nixerator-rebuild.log`.

Expected: rebuild succeeds.

- [ ] **Step 2: User verifies linger**

On qbert:

```bash
loginctl show-user $USER -p Linger
```

Expected: `Linger=yes`.

- [ ] **Step 3: User verifies the control tower service is running**

```bash
systemctl --user status claude-control-tower-qbert.service
```

Expected: `Active: active (running)`. If failed, check logs with `journalctl --user -u claude-control-tower-qbert.service -n 50` and surface to the user.

- [ ] **Step 4: User verifies the work function**

```fish
type -a work
work --help
```

Expected: function loaded; help block prints.

- [ ] **Step 5: No commit**

Verification only.

---

### Task 12: Rebuild srv and verify the retirement + control tower

srv is last because it has the most surface change (zellij-web retiring, mosh retiring, archetype enabling).

**Files:** (verification only)

- [ ] **Step 1: User runs the rebuild**

> Run `just qr` on srv. On failure, spawn the nix subagent on `/tmp/nixerator-rebuild.log`.

Expected: rebuild succeeds.

- [ ] **Step 2: User verifies zellij-web is gone**

```bash
systemctl --user status zellij-web.service 2>&1 | head -3
```

Expected: `Unit zellij-web.service could not be found.` (or, if it was running pre-rebuild, "inactive" after rebuild — followed by removal on the next user-session restart).

- [ ] **Step 3: User verifies the new tower service**

```bash
systemctl --user status claude-control-tower-srv.service
```

Expected: `Active: active (running)`.

- [ ] **Step 4: User verifies linger**

```bash
loginctl show-user $USER -p Linger
```

Expected: `Linger=yes`. (Already was, but now owned by claude-remote.)

- [ ] **Step 5: User verifies the firewall closed UDP 60000–61000**

```bash
sudo nft list ruleset | grep -E "60000|udp port" | head
```

Expected: no rules accepting UDP 60000–61000. (Mosh range is closed.)

- [ ] **Step 6: No commit**

Verification only.

---

### Task 13: Cross-host smoke test of the `work` function

End-to-end validation across the three hosts. Performed by the user on whichever host they prefer; the commands below assume starting from donkeykong but the matrix is host-symmetric.

**Files:** (verification only)

- [ ] **Step 1: Start a session on srv from donkeykong**

```fish
ssh srv -- zellij attach -c smoketest-srv -- echo hi
```

Wait for the session to spawn (zellij creates a session named `smoketest-srv` on srv). Detach via the zellij keybind or just close the SSH connection — zellij keeps the session.

- [ ] **Step 2: Start a session on qbert from donkeykong**

```fish
ssh qbert -- zellij attach -c smoketest-qbert -- echo hi
```

Same flow as above for qbert.

- [ ] **Step 3: From donkeykong, list sessions across peers**

```fish
work
```

Expected: picker (fzf if installed, numbered prompt otherwise) listing two entries:

```
smoketest-srv    (srv)
smoketest-qbert  (qbert)
```

Pick one. The function should `ssh -t … zellij attach -c …` and drop you into the session. Detach with `Ctrl-q d`.

- [ ] **Step 4: From donkeykong, target by name**

```fish
work smoketest-qbert
```

Expected: attaches directly without picker (peer match found, host-qualified `ssh -t` invocation).

- [ ] **Step 5: From donkeykong, target by `<name>@<host>`**

```fish
work smoketest-srv@srv
```

Expected: attaches directly.

- [ ] **Step 6: From donkeykong, create a brand-new session by name**

```fish
work scratch
```

Expected: no match locally, no match on peers → "creating on donkeykong" message → fresh local zellij session named `scratch`. Detach.

- [ ] **Step 7: Repeat the matrix from qbert**

ssh into qbert (or sit at it) and run `work`. Confirm the picker shows `smoketest-srv (srv)`, `scratch (donkeykong)` — wait, donkeykong is not a configured peer, so it does NOT appear. Confirm only srv-side sessions show up.

Expected outcome: peer scope = `[srv qbert]`. donkeykong sessions are NOT discovered from peers. This is by design (v1 attach-only role).

- [ ] **Step 8: Cleanup**

On srv: `zellij delete-session smoketest-srv`.
On qbert: `zellij delete-session smoketest-qbert`.
On donkeykong: `zellij delete-session scratch`.

- [ ] **Step 9: iPhone validation (manual)**

User checks:
- Termius/Blink → SSH to `srv` and `qbert` via Tailscale magicDNS. Run `work` once inside each — picker should populate immediately.
- claude.ai/code → "Add new endpoint" / browse remote controls. Confirm two entries appear: `claude-control-tower-srv` and `claude-control-tower-qbert`. Spawn a new session on each to confirm both work.

- [ ] **Step 10: No commit**

Verification only.

---

### Task 14: Document the workflow in `.claude/docs/`

Add a topic file so future Claude sessions can discover the workflow when the user asks about cross-device pickup or about the `work` function.

**Files:**

- Create: `.claude/docs/cross-device-workflow.md`
- Modify: `CLAUDE.md` (add Topics entry)

- [ ] **Step 1: Create the topic file**

```markdown
# Cross-device Claude workflow

Two peer work hosts: `srv` (always-on) and `qbert` (workstation, occasional). Both run `claude-control-tower-${hostname}` and zellij; both are reachable over SSH on the tailnet. Sessions live on the host where they were started; no cross-host state sync.

## Verbs

- `work` — across-peer session picker (fzf or numbered prompt).
- `work <name>` — attach locally, fall back to a peer, create locally if nowhere.
- `work <name>@<host>` — force a host.
- `work --here <name>` — force the current host even if a peer has the name.

## iPhone

- **Resume:** Termius / Blink / Prompt over Tailscale → `ssh srv` (or `qbert`) → `work`. SSH only — no mosh, no zellij-web.
- **Spawn:** claude.ai/code → pick `claude-control-tower-srv` or `claude-control-tower-qbert` → start a new session in a repo.

## /github-issue

Auto-renames the zellij session to `<repo>#<N>` when invoked inside zellij. An issue kicked off from the iPhone is then discoverable from any other device via `work <repo>#<N>`.

## Components

- `archetypes.claudeWorkHost` (enabled on srv + qbert) — bundles zellij + claude-remote + control tower + ssh + work-launcher.
- `apps.cli.work-launcher` (enabled everywhere) — ships the `work` fish function. `peers` defaults to `[srv qbert]`.
- `apps.cli.claude-remote` — the systemd `--user` control tower (per-host name).

## What is NOT here

- No mosh. No zellij-web. No syncthing of `~/.claude` or worktrees. No cross-host worktree sync. Branches move via `git push`/`git pull` only.
```

- [ ] **Step 2: Add the Topics entry**

Open `CLAUDE.md` (project root). In the `## Topics` section, add:

```markdown
- When the user asks about cross-device session pickup, the `work` fish function, the `claudeWorkHost` archetype, or how to attach to a session from the iPhone, read `.claude/docs/cross-device-workflow.md`.
```

- [ ] **Step 3: No format/lint**

Markdown only.

- [ ] **Step 4: Suggested commit**

```
docs: add cross-device workflow topic file

Indexed in CLAUDE.md so future Claude sessions can discover the workflow
(work function, claudeWorkHost archetype, iPhone flows, /github-issue
session renaming) when the user references it.
```

---

### Task 15: Spec ↔ plan reconciliation

Final spec-coverage pass — the open questions section of the design lists three items; this task closes them.

- [ ] **Step 1: Verify zellij-enable is idempotent on workstations**

The workstation archetype enables `terminal.enable`, which enables `apps.cli.zellij`. The new `claudeWorkHost` archetype on qbert also enables `apps.cli.zellij`. Both set the same attribute to `true` with the same sub-options — nix merges identical attribute values without conflict. No action needed; just confirm no `error: The option … has conflicting definition values` appears during qbert eval (Task 8).

- [ ] **Step 2: Decide on `peers` default**

The default `[ "srv" "qbert" ]` is intentionally a user-specific list. Leave as-is; if a second operator ever inherits this flake, they will set their own `peers` in host configs.

- [ ] **Step 3: Schedule the `/github-issue` skill patch**

Out of this repo. Open a separate `~/.claude/skills/github-issue/` change that adds, after worktree creation:

```bash
if [ -n "${ZELLIJ:-}" ]; then
  zellij action rename-session "${repo_basename}#${issue_number}" || true
fi
```

Track separately; not blocking this PR.

- [ ] **Step 4: No commit (planning only)**

---

## Self-review checklist

Run mentally before marking the plan complete:

- [x] Every "Modify" step names a concrete file + change.
- [x] Every "Create" step contains the full file body.
- [x] Every code block is complete (no `…` ellipses inside code that needs to be typed verbatim).
- [x] No "TBD", "TODO", "implement later" markers.
- [x] No `git commit` or `git push` commands appear in any step (per project convention).
- [x] Rebuild order is donkeykong → qbert → srv (smallest blast radius first).
- [x] iPhone validation is in Task 13 step 9, end-to-end through both SSH and claude.ai/code.
- [x] Both halves of the linger relocation are present (Task 4 adds, Task 5 removes).
- [x] Both halves of the control-tower rename are present (service name + `--name` flag in Task 4).
- [x] Mosh retirement covers both the suite (Task 6) and srv's explicit enable (Task 7).
