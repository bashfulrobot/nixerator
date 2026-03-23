{ hostname, globals, ... }:

{
  # Import hardware configuration
  imports = [
    ./hardware-configuration.nix # Hardware-specific settings (generated with --no-filesystems)
    ./disko.nix # Disko declarative disk partitioning
    ./boot.nix # Bootloader with LUKS encryption support
    ./usb-wakeup.nix # Comprehensive wakeup configuration for laptop
    ./modules.nix # Module configuration

    # Auto-import all modules
    ../../modules
  ];

  # Networking
  networking.hostName = hostname;

  # Localization (from globals)
  # Note: timezone is managed by services.automatic-timezoned (enabled in core suite)
  i18n.defaultLocale = globals.defaults.locale;

  # Voxtype on donkeykong (hyprflake currently supports local package/model controls only)
  hyprflake.desktop.voxtype = {
    enable = true;
    model = "base.en";
  };

  # Enable archetypes
  archetypes.workstation.enable = true;
}
