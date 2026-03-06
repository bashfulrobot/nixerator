# Adding a New Host

## Quick Start

1. Create `hosts/newhostname/`
2. Generate hardware config
3. Add host files (configuration.nix, boot.nix, modules.nix, home.nix)
4. Add to `flake.nix`
5. Rebuild

## Generate Hardware Config

Boot target with NixOS installer:

```bash
nixos-generate-config --no-filesystems --show-hardware-config > hardware-configuration.nix
```

Copy to `hosts/newhostname/`.

## Host File Templates

### configuration.nix

```nix
{ hostname, globals, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./modules.nix
    ../../modules
  ];
  networking.hostName = hostname;
  i18n.defaultLocale = globals.defaults.locale;
  archetypes.workstation.enable = true;  # or server
}
```

### boot.nix

```nix
{ ... }:
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

## Add to flake.nix

```nix
nixosConfigurations.newhostname = lib.mkHost {
  inherit globals versions;
  hostname = "newhostname";
  system = "x86_64-linux";
  extraModules = [ inputs.hyprflake.nixosModules.default ];           # desktop
  homeManagerModules = [ inputs.spicetify-nix.homeManagerModules.default ];
};
```

## Optional: Disko

Create `disko.nix`, import it in `configuration.nix`, and add `inputs.disko.nixosModules.disko` to `extraModules` in `flake.nix`.

## Deploy

```bash
# First install (from NixOS installer)
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko --flake ".#newhostname"
sudo nixos-install --flake .#newhostname

# Subsequent rebuilds
sudo nixos-rebuild switch --flake .#newhostname
```

## Server Hosts

Server hosts (using `archetypes.server`) do not auto-import all modules. Unlike workstations, you must manually import each needed module path in `modules.nix` alongside setting the enable option. See `hosts/srv/modules.nix` for an example.

## Checklist

- [ ] `hosts/newhostname/` directory
- [ ] `hardware-configuration.nix` generated
- [ ] `configuration.nix` with imports + archetype
- [ ] `boot.nix`, `modules.nix`, `home.nix`
- [ ] Added to `flake.nix` nixosConfigurations
- [ ] (Optional) `disko.nix`, GPU config, hardware-specific modules
