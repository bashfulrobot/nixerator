{ hostname, globals, ... }:

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

  # Localization (from globals)
  # Note: timezone is managed by services.automatic-timezoned (enabled in core suite)
  i18n.defaultLocale = globals.defaults.locale;

  # Enable archetypes
  archetypes.workstation.enable = true;
}
