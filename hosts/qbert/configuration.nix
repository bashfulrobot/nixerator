{ hostname, globals, inputs, pkgs, ... }:

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

  # Voxtype on qbert: keep thread cap + use Vulkan backend (AMD 6800 XT)
  hyprflake.desktop.voxtype = {
    model = "large-v3-turbo";
    threads = 16;
    package = inputs.hyprflake.inputs.voxtype.packages.${pkgs.system}.vulkan;
  };

  # Enable archetypes
  archetypes.workstation.enable = true;
}
