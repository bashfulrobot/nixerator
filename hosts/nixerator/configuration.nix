{ config, pkgs, inputs, hostname, username, globals, ... }:

{
  # Import hardware configuration
  # You'll need to generate this with: nixos-generate-config --show-hardware-config > hosts/nixerator/hardware-configuration.nix
  imports = [
    ./hardware-configuration.nix
    ./boot.nix  # Bootloader configuration (update based on your system)
    ./vm.nix    # VM-specific configuration (comment out for bare metal)

    # Auto-import all modules
    ../../modules
  ];

  # Networking
  networking.hostName = hostname;

  # Time zone and localization (from globals)
  time.timeZone = globals.defaults.timeZone;
  i18n.defaultLocale = globals.defaults.locale;

  # Enable archetypes
  archetypes.workstation.enable = true;
}
