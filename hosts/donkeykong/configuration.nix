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

  # Touchpad palm rejection: keyd's virtual keyboard is not recognized as
  # "internal" by libinput, which breaks disable-while-typing detection.
  # This quirk tells libinput to treat it as a built-in keyboard.
  environment.etc."libinput/local-overrides.quirks".text = ''
    [keyd virtual keyboard]
    MatchUdevType=keyboard
    MatchName=keyd virtual keyboard
    AttrKeyboardIntegration=internal
  '';

  # Ensure disable-while-typing is active at the libinput level
  services.libinput.touchpad.disableWhileTyping = true;

  # Enable archetypes
  archetypes.workstation.enable = true;
}
