{ config, pkgs, inputs, hostname, username, globals, ... }:

{
  # Import hardware configuration
  imports = [
    ./hardware-configuration.nix  # Hardware-specific settings (generated with --no-filesystems)
    ./disko.nix                   # Disko declarative disk partitioning
    ./boot.nix                    # Bootloader with LUKS encryption support
    ./usb-wakeup.nix              # Comprehensive wakeup configuration for laptop

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
