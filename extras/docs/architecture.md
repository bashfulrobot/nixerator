# Architecture

Modular NixOS configuration with flakes, home-manager, and auto-imported modules.

## Directory Structure

```
nixerator/
├── flake.nix / flake.lock
├── settings/
│   ├── globals.nix        # User, paths, timezone, editor, etc.
│   └── versions.nix       # Centralized version pins
├── lib/
│   ├── mkHost.nix         # Host builder
│   └── mkWebApp.nix       # Web app (PWA) module factory
├── modules/
│   ├── archetypes/        # workstation, server
│   ├── suites/            # Feature bundles (core, dev, desktop, ...)
│   ├── apps/cli/          # CLI apps (module-local packages in build/)
│   ├── apps/gui/          # GUI apps
│   ├── apps/webapps/      # PWAs
│   ├── system/            # System services (ssh, flatpak, nix)
│   ├── server/            # Server modules (kvm, nfs, restic)
│   └── dev/               # Dev environments (go, ...)
├── hosts/                 # Per-host configs (donkeykong, qbert, srv)
└── extras/                # Docs, helper scripts
```

## Auto-Import

`modules/default.nix` recursively imports all `*.nix` files except those in:

- `disabled/` -- disabled modules
- `build/` -- module-local package derivations
- `cfg/` -- configuration fragments
- `reference/` -- reference docs
- `archive/` -- retired modules kept for reference, not evaluated (original relative path preserved under `archive/<path>` for easy restore)

Mechanism: `inputs.import-tree.filterNot <predicate> ./.` (see [denful/import-tree](https://github.com/denful/import-tree)). The `.filterNot` predicate in `modules/default.nix` carries the exclusion list above; add a pattern there to introduce a new convention. import-tree also silently skips anything containing `/_` in its path (upstream default).

## Namespacing

- `apps.cli.*` -- CLI applications
- `apps.gui.*` -- GUI applications
- `apps.webapps.*` -- Progressive web apps
- `suites.*` -- Module collections
- `system.*` -- System-level settings
- `dev.*` -- Development tools

## Module Template

```nix
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.cli.APPNAME;
in
{
  options.apps.cli.APPNAME.enable = lib.mkEnableOption "APPNAME";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.APPNAME ];
  };
}
```

## Archetypes

- `archetypes.workstation.enable = true;` -- enables: core, desktop, terminal, browsers, security, dev, offcomms, infrastructure, k8s, kong, av, ai
- `archetypes.server.enable = true;` -- enables: terminal, system.ssh, apps.cli.tailscale

## Suites

| Suite          | Key Modules                                             |
| -------------- | ------------------------------------------------------- |
| core           | SSH, Flatpak, Tailscale, Backrest + Restic, Web App Hub |
| desktop        | hyprflake integration                                   |
| terminal       | fish, starship, helix, zoxide                           |
| browsers       | Brave, Chrome                                           |
| security       | 1Password                                               |
| dev            | Claude Code, VS Code, git, helix, Go                    |
| offcomms       | Signal, Obsidian                                        |
| infrastructure | Cloud CLI tools                                         |
| k8s            | kubectl                                                 |
| av             | Affinity, Jellyfin Desktop, Spotify, VLC, mpv           |
| kong           | Insomnia, deck, Salesforce CLI, Calendar                |
| ai             | Claude Code (agent-scan, agentos), Gemini CLI           |

## Globals

`settings/globals.nix` -- access via `globals.user.name`, `globals.paths.nixerator`, etc.

```nix
rec {
  user = { name = "dustin"; fullName = "Dustin Krysak"; email = "dustin@bashfulrobot.com"; homeDirectory = "/home/dustin"; };
  paths = { devRoot = "${user.homeDirectory}/git"; nixerator = "${user.homeDirectory}/git/nixerator"; ... };
  defaults = { stateVersion = "25.11"; timeZone = "America/Vancouver"; locale = "en_US.UTF-8"; };
  preferences = { editor = "helix"; shell = "fish"; };
}
```

## mkHost

```nix
# flake.nix
nixosConfigurations.donkeykong = lib.mkHost {
  hostname = "donkeykong";
  system = "x86_64-linux";
};
```

Active outputs: `donkeykong`, `qbert`, `srv`.

## Per-Host File Layout

```
hosts/<hostname>/
├── configuration.nix          # Main entry, module imports, archetype
├── hardware-configuration.nix # Auto-generated
├── home.nix                   # Home Manager config
├── modules.nix                # Host-specific enables
├── boot.nix                   # (optional) Bootloader, LUKS
└── disko.nix                  # (optional) Declarative partitioning
```

## Design Principles

1. **Modular** -- everything is a module with `enable` option
2. **Declarative** -- configuration as code, version controlled
3. **Composable** -- combine modules via suites or individual enables
4. **Discoverable** -- auto-import eliminates manual imports
5. **Portable** -- same config works across systems
6. **Namespaced** -- clear organization by category
