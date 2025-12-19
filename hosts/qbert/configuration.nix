{ config, pkgs, inputs, hostname, username, globals, ... }:

{
  # Import hardware configuration
  imports = [
    ./hardware-configuration.nix  # Hardware-specific settings (generated with --no-filesystems)
    ./disko.nix                   # Disko declarative disk partitioning
    ./boot.nix                    # Bootloader with bcachefs support
    ./gpu.nix                     # AMD GPU configuration
    ./usb-wakeup.nix              # USB wakeup configuration for Logitech devices
    ./reboot-windows.nix          # Desktop entry for rebooting to Windows

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
