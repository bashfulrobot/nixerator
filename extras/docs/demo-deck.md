---
theme: default
title: Nixerator
info: A modular, declarative NixOS configuration system
author: Dustin Krysak
transition: slide-left
mdc: true
---

# Nixerator

A modular, declarative NixOS configuration system

<br>

**3 hosts** / **118 modules** / **13 suites** / **18 flake inputs**

<br>

<small>dustin@bashfulrobot.com</small>

---

# What Is Nixerator?

A single flake-based repo that declaratively manages every aspect of multiple NixOS machines.

<br>

- **Workstations**: donkeykong (ThinkPad T14), qbert (desktop)
- **Server**: srv
- Every package, service, font, keybind, and desktop rule lives in version-controlled Nix

<br>

```
nixos-rebuild switch --flake .#donkeykong
```

---
layout: two-cols
---

# Repo Layout

```
flake.nix          # entry point
settings/
  globals.nix      # user, paths, prefs
hosts/
  donkeykong/      # per-host config
  qbert/
  srv/
modules/           # the bulk of the repo
  apps/cli/        # 33+ CLI tools
  apps/gui/        # 20+ GUI apps
  apps/webapps/    # 8 PWAs
  archetypes/      # workstation / server
  suites/          # 13 feature bundles
  system/          # 7 system services
  server/          # 4 server modules
  dev/             # dev environments
lib/               # mkHost, mkWebApp, autoimport
extras/            # docs, scripts, helpers
secrets/           # git-crypt encrypted
```

::right::

# Key Files

<br>

| File | Purpose |
|------|---------|
| `flake.nix` | Inputs + host outputs |
| `globals.nix` | Shared user/path/pref config |
| `lib/mkHost.nix` | Host builder abstraction |
| `lib/autoimport.nix` | Recursive module discovery |
| `lib/mkWebApp.nix` | PWA module factory |
| `justfile` | Rebuild, upgrade, clean shortcuts |

---

# The Module System

Every feature is a self-contained module with an `enable` toggle.

```nix
# modules/apps/cli/slidev/default.nix
{ lib, config, pkgs, globals, ... }:
let
  cfg = config.apps.cli.slidev;
in {
  options.apps.cli.slidev.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Slidev presentation tool.";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.packages = [ pkgs.slidev-cli ];
    };
  };
}
```

Drop a `default.nix` in the right directory and it auto-imports. No manual wiring.

---

# Auto-Import

`lib/autoimport.nix` recursively scans `modules/` and imports everything automatically.

```
modules/
  apps/cli/fish/default.nix    -->  config.apps.cli.fish
  apps/gui/obsidian/default.nix -->  config.apps.gui.obsidian
  suites/dev/default.nix       -->  config.suites.dev
  system/ssh/default.nix       -->  config.system.ssh
```

<br>

**Excluded directories** (for local helpers, not modules):

- `disabled/` -- parked modules
- `build/` -- module-local package derivations
- `cfg/` -- configuration fragments
- `reference/` -- reference material

---

# Suites and Archetypes

**Suites** bundle related modules into a single toggle.

```nix
# suites/dev enables:
apps.cli.claude-code, apps.cli.git, apps.cli.helix,
apps.gui.vscode, apps.gui.zed, dev.go ...
```

<br>

**Archetypes** compose suites into machine profiles.

```nix
# archetypes/workstation enables:
suites.core, suites.desktop, suites.terminal,
suites.browsers, suites.security, suites.dev,
suites.offcomms, suites.infrastructure, suites.k8s,
suites.kong, suites.av, suites.ai
```

<br>

```
archetype --> suites --> modules --> packages & config
```

---

# Host Configuration

Each host has a focused set of files:

```
hosts/donkeykong/
  configuration.nix        # main entry, archetype selection
  modules.nix              # host-specific module overrides
  boot.nix                 # bootloader & encryption
  disko.nix                # declarative disk partitioning
  hardware-configuration.nix
  home.nix                 # home-manager extras
```

<br>

The `lib/mkHost.nix` builder wires everything together:

- Loads host files + global settings + versions
- Configures Home Manager, Nix GC, overlays
- Passes `globals`, `versions`, `secrets` as special args to all modules

---

# Flake Inputs

18 upstream sources composing the system:

| Input | Purpose |
|-------|---------|
| **nixpkgs** | nixos-unstable package set |
| **home-manager** | User-level config management |
| **stylix** | System-wide theming |
| **disko** | Declarative disk partitioning |
| **hyprflake** | Hyprland desktop integration |
| **spicetify-nix** | Spotify theming |
| **apple-fonts** | Apple font derivations |
| **nix-flatpak** | Flatpak support |
| **nixos-hardware** | Hardware quirks |
| **determinate** | DeterminateSystems Nix |
| **upsight, paseo, wayscriber** | Custom tools |

---

# Global Settings

`settings/globals.nix` -- single source of truth for identity and preferences.

```nix
{
  user = {
    name = "dustin";
    fullName = "Dustin Krysak";
    email = "dustin@bashfulrobot.com";
    homeDirectory = "/home/dustin";
  };

  defaults = {
    stateVersion = "25.11";
    timeZone = "America/Vancouver";
  };

  preferences = {
    editor = "helix";
    shell = "fish";
    browser = "google-chrome-stable";
    terminal = "ghostty";
  };

  tailscale = {
    qbert = "100.74.137.95";
    donkeykong = "100.117.210.113";
    srv = "100.64.187.14";
  };
}
```

---

# Day-to-Day Operations

The `justfile` provides ergonomic shortcuts:

| Command | What it does |
|---------|-------------|
| `just rebuild` / `just r` | Production rebuild with spinner & warnings |
| `just upgrade` / `just up` | Flake update + rebuild + post-setup |
| `just clean 5` / `just gc` | Garbage collect generations older than N days |
| `just gc-nuclear` | Full cleanup: old gens + GC + store optimize |
| `just health` | Run deadnix + statix linters |
| `just fmt` | Format all Nix files |
| `just sync-git` | Smart push/pull with syncthing pause |
| `just quiet-rebuild` | Silent rebuild, logs to /tmp on failure |

---

# Module Highlights

<br>

**91 app modules** across three categories:

<br>

| Category | Count | Examples |
|----------|-------|---------|
| **CLI** | 33+ | fish, helix, git, docker, claude-code, ollama, pandoc |
| **GUI** | 20+ | 1Password, Chrome, Obsidian, Signal, Ghostty, VS Code, Zed |
| **WebApps** | 8 | Gmail, Calendar, Slack, Zoom (Chrome PWAs via mkWebApp) |
| **System** | 7 | SSH, Flatpak, Nix settings, special workspaces, fonts |
| **Server** | 4 | KVM, NFS, Restic backup, Whisper server |

---

# Design Principles

<br>

- **Everything is a module** -- no loose config, every feature has an enable toggle
- **Auto-discovery** -- drop a file, it imports; no registration step
- **Composition over inheritance** -- suites compose modules, archetypes compose suites
- **One repo, many machines** -- same patterns for workstations and servers
- **Secrets stay encrypted** -- git-crypt for anything sensitive
- **Docs live with code** -- 21 guides in `extras/docs/`
- **No manual rebuilds in CI** -- `just` recipes handle the ceremony

---
layout: center
---

# Questions?

<br>

github.com/bashfulrobot/nixerator
