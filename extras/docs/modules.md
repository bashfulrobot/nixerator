# Module System Reference

Nixerator uses a hierarchical module system with auto-import, suites, and archetypes.

## Directory Structure

```
modules/
├── archetypes/           # High-level host profiles
│   ├── workstation/      # Desktop/laptop with full suite
│   └── server/           # Minimal server configuration
├── suites/               # Feature bundles
│   ├── core/             # SSH, Flatpak, Tailscale, backup tools, essential tools
│   ├── desktop/          # Hyprland desktop environment
│   ├── terminal/         # Shell, prompt, terminal tools
│   ├── browsers/         # Web browsers
│   ├── security/         # 1Password, security tools
│   ├── dev/              # Development tools, AI assistants
│   ├── offcomms/         # Communications (Signal, Obsidian)
│   ├── infrastructure/   # Cloud tools
│   ├── k8s/              # Kubernetes tooling
│   ├── av/               # Audio/visual creative tooling
│   ├── media/            # Media applications
│   ├── kong/             # Kong API Gateway tools
│   ├── ai/               # AI tooling
│   └── webapps/          # Web application launchers
├── apps/                 # Individual applications
│   ├── cli/              # CLI applications
│   ├── gui/              # GUI applications
│   └── webapps/          # Web app desktop entries
├── system/               # System services
│   ├── ssh/              # SSH server configuration
│   ├── flatpak/          # Flatpak support
│   └── nix/              # Nix daemon settings
├── server/               # Server-specific modules
│   ├── kvm/              # KVM/libvirt virtualization
│   ├── nfs/              # NFS server
│   └── restic/           # Backrest + Restic backup server module
└── dev/                  # Development environments
    └── go/               # Go development setup
```

## Archetypes

Archetypes are high-level host profiles that enable groups of suites.

### workstation

Full desktop environment with all productivity suites:

```nix
archetypes.workstation.enable = true;
```

Enables: core, desktop, terminal, browsers, security, dev, offcomms, infrastructure, k8s, media, kong, av, ai

### server

Minimal server with essential services:

```nix
archetypes.server.enable = true;
```

Enables: terminal, system.ssh, apps.cli.tailscale

## Suites

Suites bundle related modules. Enable them individually or via archetypes.

| Suite | Description | Key Modules |
|-------|-------------|-------------|
| core | Essential infrastructure | SSH, Flatpak, Tailscale, Backrest + Restic backup tools, Web App Hub |
| desktop | Hyprland environment | hyprflake integration |
| terminal | Shell environment | fish, starship, helix, zoxide |
| browsers | Web browsers | Brave, Chrome |
| security | Security tools | 1Password |
| dev | Development tools | Claude Code, VS Code, git, helix, Go |
| offcomms | Communications | Signal, Obsidian |
| infrastructure | Cloud tools | Various CLI tools |
| k8s | Kubernetes | kubectl |
| av | Audio/visual creative tools | Affinity, noisetorch, Jellyfin Desktop |
| media | Media apps | Spotify (spicetify) |
| kong | API Gateway | Insomnia, Kong docs |
| ai | AI tooling | happy, ollama, termly, yepanywhere |
| webapps | Web launchers | Calendar, Mail, Clari |

## Auto-Import System

Modules are auto-imported from `modules/` using `lib/autoimport.nix`.

### Default Exclusions

These directory patterns are excluded from auto-import:

- `disabled/` - Disabled modules
- `build/` - Build scripts and module-local package derivations
- `cfg/` - Configuration fragments
- `reference/` - Reference documentation

### Using Auto-Import

```nix
# In configuration.nix
imports = [
  ../../modules  # Auto-imports all modules
];
```

### Custom Exclusions

```nix
let
  autoImportLib = import ../lib/autoimport.nix { inherit lib; };
in
autoImportLib.customAutoImport ./modules [ "experimental" ]
```

### Debug Mode

Enable trace output to see which files are imported:

```nix
autoImportLib.tracedAutoImport ./modules []
```

## Module Patterns

### Standard Module Structure

```nix
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.cli.myapp;
in
{
  options.apps.cli.myapp.enable = lib.mkEnableOption "myapp CLI tool";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.myapp ];
  };
}
```

### Home Manager Integration

```nix
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.cli.myapp;
in
{
  options.apps.cli.myapp.enable = lib.mkEnableOption "myapp";

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      programs.myapp.enable = true;
    };
  };
}
```

### Module-Local Package Derivations

For custom packages used by a single module (or a small local group), keep the derivation in `build/default.nix` next to the module and call it locally:

```nix
{ lib, pkgs, config, ... }:

let
  cfg = config.apps.cli.myapp;
  myapp = pkgs.callPackage ./build { };
in
{
  options.apps.cli.myapp.enable = lib.mkEnableOption "myapp";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ myapp ];
  };
}
```

This keeps package wiring local and avoids global overlay sprawl.

### Suite Pattern

```nix
{ lib, config, ... }:

let
  cfg = config.suites.mysuite;
in
{
  options.suites.mysuite.enable = lib.mkEnableOption "my suite";

  config = lib.mkIf cfg.enable {
    # Enable component modules
    apps.cli.tool1.enable = true;
    apps.cli.tool2.enable = true;
    apps.gui.app1.enable = true;
  };
}
```

## Globals

Shared configuration is in `settings/globals.nix`:

```nix
rec {
  user = {
    name = "dustin";
    fullName = "Dustin Krysak";
    email = "dustin@bashfulrobot.com";
    homeDirectory = "/home/dustin";
  };

  paths = {
    devRoot = "${user.homeDirectory}/dev";
    nixRoot = "${user.homeDirectory}/dev/nix";
    nixerator = "${user.homeDirectory}/dev/nix/nixerator";
    hyprflake = "${user.homeDirectory}/dev/nix/hyprflake";
  };

  defaults = {
    stateVersion = "25.11";
    timeZone = "America/Vancouver";
    locale = "en_US.UTF-8";
  };

  preferences = {
    editor = "helix";
    shell = "fish";
  };
}
```

Access in modules via `globals.user.name`, `globals.paths.nixerator`, `globals.defaults.locale`, etc.
