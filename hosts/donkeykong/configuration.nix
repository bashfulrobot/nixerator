{ hostname, globals, ... }:

{
  # Import hardware configuration
  imports = [
    ./hardware-configuration.nix  # Hardware-specific settings (generated with --no-filesystems)
    ./disko.nix                   # Disko declarative disk partitioning
    ./boot.nix                    # Bootloader with LUKS encryption support
    ./usb-wakeup.nix              # Comprehensive wakeup configuration for laptop
    ./modules.nix                 # Module configuration

    # Auto-import all modules
    ../../modules
  ];

  # Networking
  networking.hostName = hostname;

  # Localization (from globals)
  # Note: timezone is managed by services.automatic-timezoned (enabled in core suite)
  i18n.defaultLocale = globals.defaults.locale;

  # Voxtype on donkeykong: offload transcription to qbert's GPU via Tailscale
  hyprflake.desktop.voxtype = {
    backend = "remote";
    remoteEndpoint = "http://${globals.tailscale.qbert}:8080";
    remoteTimeoutSecs = 30;
    language = "en";
  };

  # Enable archetypes
  archetypes.workstation.enable = true;
}
