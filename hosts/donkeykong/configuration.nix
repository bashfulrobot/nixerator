{ hostname, globals, inputs, pkgs, ... }:

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

  # Voxtype on donkeykong: keep thread cap + try Vulkan backend (Intel Arc iGPU)
  hyprflake.desktop.voxtype = {
    threads = 8;
    package = inputs.hyprflake.inputs.voxtype.packages.${pkgs.system}.vulkan;
  };

  # Enable archetypes
  archetypes.workstation.enable = true;
}
