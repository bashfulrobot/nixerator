# Nixerator

Modular NixOS configuration with flakes, home-manager, and Hyprland desktop via [hyprflake](https://github.com/bashfulrobot/hyprflake).

## Quick Start

### Install NixOS on New System

For systems with disko (automated partitioning):

```bash
# See bootstrap.txt for complete installation guide
cat bootstrap.txt
```

For manual setup:

```bash
# 1. Boot NixOS live USB
# 2. Partition and mount disks
# 3. Generate hardware config
sudo nixos-generate-config --root /mnt
sudo cp /mnt/etc/nixos/hardware-configuration.nix /tmp/

# 4. Clone this repo
git clone git@github.com:bashfulrobot/nixerator.git /tmp/nixerator
cd /tmp/nixerator

# 5. Copy hardware config to your host
sudo cp /tmp/hardware-configuration.nix hosts/HOSTNAME/

# 6. Install
sudo nixos-install --flake .#HOSTNAME
```

### Update Existing System

```bash
cd ~/dev/nix/nixerator
sudo nixos-rebuild switch --flake .#HOSTNAME
```

## Hosts

- **nixerator** - VM development host (virtiofs shared folder)
- **donkeykong** - LUKS encrypted desktop (disko partitioning, ext4, 32GB swap)

## Common Commands

```bash
# Using justfile
just switch          # Rebuild and switch
just update          # Update flake inputs
just clean           # Garbage collect
just generations     # List generations

# Direct nix commands
sudo nixos-rebuild switch --flake .#HOSTNAME
nix flake update
```

## Configuration

Global settings: `settings/globals.nix`
- Username, timezone, locale
- Editor, shell preferences

Host-specific: `hosts/HOSTNAME/configuration.nix`
- Enable modules via options
- Example: `apps.cli.git.enable = true;`

## Structure

```
├── flake.nix              # Flake inputs and outputs
├── settings/globals.nix   # Global configuration
├── lib/                   # Helper functions
├── modules/               # Auto-imported modules
│   ├── apps/cli/          # CLI tools (git, helix, etc.)
│   ├── apps/gui/          # GUI apps (firefox, etc.)
│   └── system/            # System config
└── hosts/                 # Per-host configuration
    ├── nixerator/         # VM development host
    └── donkeykong/        # Encrypted desktop
        ├── configuration.nix
        ├── disko.nix      # Disk partitioning
        ├── boot.nix       # LUKS + hibernation
        └── home.nix       # Home-manager config
```

## Adding Modules

1. Create `modules/apps/cli/APPNAME/default.nix`
2. Define options and config (see git module as example)
3. Enable in host config: `apps.cli.APPNAME.enable = true;`
4. Auto-imported via `modules/default.nix`

## VM Development (nixerator host)

Requires virtiofs share in libvirt:

```xml
<filesystem type="mount" accessmode="passthrough">
  <driver type="virtiofs"/>
  <source dir="/path/on/host"/>
  <target dir="mount_nixerator"/>
</filesystem>
```

Initial VM setup:
```bash
sudo mkdir -p /home/dustin/dev/nix/nixerator
sudo mount -t virtiofs mount_nixerator /home/dustin/dev/nix/nixerator
cd /home/dustin/dev/nix/nixerator
sudo nixos-rebuild switch --flake .#nixerator
```

After first rebuild, mount is permanent.

## Credits

- Hyprland desktop: [bashfulrobot/hyprflake](https://github.com/bashfulrobot/hyprflake)
