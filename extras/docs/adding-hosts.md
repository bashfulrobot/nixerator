# Adding a New Host

Step-by-step guide to adding a new host to nixerator.

## Quick Start

1. Create the host directory structure
2. Generate hardware configuration
3. Add to flake.nix
4. Configure host-specific settings
5. Rebuild

## Step 1: Create Host Directory

```bash
mkdir -p hosts/newhostname
```

## Step 2: Generate Hardware Configuration

Boot the target machine with NixOS installer, then:

```bash
# Generate hardware config (without filesystem info if using disko)
nixos-generate-config --no-filesystems --show-hardware-config > hardware-configuration.nix
```

Copy this file to `hosts/newhostname/hardware-configuration.nix`.

## Step 3: Create Host Files

### configuration.nix

```nix
{ hostname, globals, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./modules.nix

    # Auto-import all modules
    ../../modules
  ];

  networking.hostName = hostname;

  # Timezone is managed by automatic-timezoned (core suite)
  i18n.defaultLocale = globals.defaults.locale;

  # Choose archetype
  archetypes.workstation.enable = true;  # or archetypes.server.enable = true;
}
```

### boot.nix

```nix
{ pkgs, ... }:

{
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
}
```

### modules.nix

```nix
_:

{
  # Host-specific module enables
  apps.cli.syncthing = {
    enable = true;
    host.newhostname = true;
  };
}
```

### home.nix

```nix
{ globals, ... }:

{
  home = {
    username = globals.user.name;
    homeDirectory = globals.user.homeDirectory;
    stateVersion = globals.defaults.stateVersion;
  };
}
```

## Step 4: Add to flake.nix

```nix
nixosConfigurations = {
  # ... existing hosts ...

  newhostname = lib.mkHost {
    inherit globals versions;
    hostname = "newhostname";
    system = "x86_64-linux";
    extraModules = [
      # Add any extra NixOS modules
      inputs.hyprflake.nixosModules.default  # For desktop
    ];
    homeManagerModules = [
      # Add any extra Home Manager modules
      inputs.spicetify-nix.homeManagerModules.default
    ];
  };
};
```

## Step 5: Optional - Disko Configuration

For declarative disk partitioning, create `disko.nix`:

```nix
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";  # Adjust for your hardware
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
```

Add to imports in `configuration.nix`:

```nix
imports = [
  ./disko.nix
  # ...
];
```

And add disko module in `flake.nix`:

```nix
extraModules = [
  inputs.disko.nixosModules.disko
  # ...
];
```

## Step 6: Build and Deploy

### First-time installation (from installer):

```bash
# Partition disk with disko (if using)
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./hosts/newhostname/disko.nix

# Install NixOS
sudo nixos-install --flake .#newhostname
```

### Subsequent rebuilds:

```bash
sudo nixos-rebuild switch --flake .#newhostname
```

## Common Additions

### GPU Configuration

Create `gpu.nix`:

```nix
{ config, ... }:

{
  # AMD GPU
  programs.hyprflake.amd = true;

  # Or NVIDIA
  # programs.hyprflake.nvidia = true;

  # Or Intel
  # programs.hyprflake.intel = true;
}
```

### Static Networking (servers)

```nix
networking = {
  useDHCP = false;
  interfaces.eth0 = {
    useDHCP = false;
    ipv4.addresses = [{
      address = "192.168.1.100";
      prefixLength = 24;
    }];
  };
  defaultGateway = "192.168.1.1";
  nameservers = [ "1.1.1.1" ];
};
```

### Hardware-Specific Modules

For supported hardware, add nixos-hardware:

```nix
# In flake.nix extraModules
inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-intel-gen6
```

## Checklist

- [ ] `hosts/newhostname/` directory created
- [ ] `hardware-configuration.nix` generated
- [ ] `configuration.nix` with imports and archetype
- [ ] `boot.nix` with bootloader config
- [ ] `modules.nix` with host-specific enables
- [ ] `home.nix` with Home Manager base config
- [ ] Added to `flake.nix` nixosConfigurations
- [ ] (Optional) `disko.nix` for declarative partitioning
- [ ] (Optional) GPU configuration
- [ ] (Optional) Host-specific power management
