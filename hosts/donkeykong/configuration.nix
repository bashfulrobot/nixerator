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

  # donkeykong is a laptop (Lenovo ThinkPad T14 Intel gen6). This enables
  # UPower for battery monitoring and shows the DMS battery / power-profile bar
  # widget. Desktops leave hyprflake.system.isLaptop at its false default.
  hyprflake.system.isLaptop = true;

  # Use power-profiles-daemon as the backend so the DMS panel applet can switch
  # profiles — it drives ppd over D-Bus (net.hadess.PowerProfiles), and TLP
  # provides no such interface. nixos-hardware stands TLP down automatically
  # (services.tlp.enable = mkDefault (!power-profiles-daemon.enable)).
  # Trade-off: this drops TLP's battery charge-threshold cap; profile switching
  # from the bar is preferred over the 80% limit here.
  hyprflake.system.power.profilesBackend = "power-profiles-daemon";

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
