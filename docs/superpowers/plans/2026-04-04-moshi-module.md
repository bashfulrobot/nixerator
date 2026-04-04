# Moshi Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `system.moshi` module that installs mosh + tmux with sane defaults, enabled from the AI suite.

**Architecture:** Single NixOS module at `modules/system/moshi/default.nix` combining mosh (system-level firewall + package) with tmux (Home Manager `programs.tmux`). Enabled via `suites/ai`.

**Tech Stack:** NixOS module system, Home Manager `programs.tmux`, `pkgs.mosh`

---

### Task 1: Create the moshi module

**Files:**
- Create: `modules/system/moshi/default.nix`

- [ ] **Step 1: Create the module file**

```nix
{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.system.moshi;
in
{
  options = {
    system.moshi.enable = lib.mkEnableOption "Moshi - mosh server and tmux with sane defaults";
  };

  config = lib.mkIf cfg.enable {

    # Mosh: install package and open UDP ports
    environment.systemPackages = [ pkgs.mosh ];
    networking.firewall.allowedUDPPortRanges = [
      {
        from = 60000;
        to = 61000;
      }
    ];

    # Tmux: Home Manager programs.tmux with sane defaults
    home-manager.users.${globals.user.name} = {
      programs.tmux = {
        enable = true;
        mouse = true;
        historyLimit = 50000;
        baseIndex = 1;
        terminal = "tmux-256color";
        escapeTime = 0;
        aggressiveResize = true;
        prefix = "C-a";
        keyMode = "vi";
      };
    };
  };
}
```

- [ ] **Step 2: Verify file exists and has correct path**

Run: `cat modules/system/moshi/default.nix | head -5`
Expected: the `{` and argument list of the module

### Task 2: Enable moshi in the AI suite

**Files:**
- Modify: `modules/suites/ai/default.nix:15-54`

- [ ] **Step 1: Add `system.moshi.enable = true;` to the AI suite**

In `modules/suites/ai/default.nix`, inside the `config = lib.mkIf cfg.enable {` block, add:

```nix
    system.moshi.enable = true;
```

Place it after the `apps.cli` block closing brace (after line 53), before the final closing braces. The result should look like:

```nix
  config = lib.mkIf cfg.enable {
    apps.gui = {
    };

    apps.cli = {
      # ... existing entries ...
    };

    system.moshi.enable = true;
  };
```

### Task 3: Build and verify

- [ ] **Step 1: Run a quiet rebuild to verify the module evaluates correctly**

Run: `just quiet-rebuild`

If it fails, read `/tmp/nixerator-rebuild.log` to diagnose. Common issues:
- Typo in option name: check `system.moshi` namespace matches
- Missing argument: ensure `globals` is in the function args
- Port range syntax: `allowedUDPPortRanges` takes a list of `{ from; to; }` attrsets

- [ ] **Step 2: Verify mosh is available after rebuild**

Run: `which mosh-server && mosh-server --version`
Expected: path to mosh-server and version output

- [ ] **Step 3: Verify tmux is configured**

Run: `tmux -V && grep -c "set -g mouse on" ~/.config/tmux/tmux.conf`
Expected: tmux version and a match count of 1

- [ ] **Step 4: Verify firewall ports are open**

Run: `sudo iptables -L -n | grep "60000:61000"`
Expected: a UDP ACCEPT rule for the mosh port range

- [ ] **Step 5: Commit**

```bash
git add modules/system/moshi/default.nix modules/suites/ai/default.nix
git commit -m "feat(moshi): add mosh server and tmux module"
```
