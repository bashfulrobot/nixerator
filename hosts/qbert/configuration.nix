{ hostname, globals, ... }:

{
  # Import hardware configuration
  imports = [
    ./hardware-configuration.nix  # Hardware-specific settings (generated with --no-filesystems)
    ./disko.nix                   # Disko declarative disk partitioning
    ./boot.nix                    # Bootloader with bcachefs support
    ./gpu.nix                     # AMD GPU configuration
    ./power-management.nix        # Power management workarounds for AMD GPU suspend and USB wakeup
    ./reboot-windows.nix          # Desktop entry for rebooting to Windows
    ./modules.nix                 # Module configuration

    # Auto-import all modules
    ../../modules
  ];

  # Networking
  networking.hostName = hostname;
  networking.interfaces.enp34s0.wakeOnLan.enable = true;

  # Localization (from globals)
  # Note: timezone is managed by services.automatic-timezoned (enabled in core suite)
  i18n.defaultLocale = globals.defaults.locale;

  # Voxtype whisper threads (16 cores)
  hyprflake.desktop.voxtype.threads = 16;

  # Enable archetypes
  archetypes.workstation.enable = true;
}
