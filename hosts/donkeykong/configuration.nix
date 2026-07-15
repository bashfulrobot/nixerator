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

  # donkeykong is a laptop (Lenovo ThinkPad T14 Intel gen6). isLaptop enables
  # UPower for battery monitoring, shows the DMS battery / power-profile bar
  # widget, and defaults the power-profile backend to power-profiles-daemon so
  # the DMS applet can switch profiles (it drives ppd over D-Bus; TLP provides
  # no such interface). nixos-hardware stands TLP down automatically. Desktops
  # leave hyprflake.system.isLaptop at its false default.
  hyprflake.system.isLaptop = true;

  # Voxtype on donkeykong: offload inference to the Intel Arc iGPU via Vulkan.
  # This cuts the transcription delay of the CPU path; base.en keeps it fast.
  # (Needs voxtype >= 0.7.3, which fixed a Vulkan SIGILL on Intel CPUs.)
  hyprflake.desktop.voxtype = {
    enable = true;
    model = "base.en";
    acceleration = "vulkan";
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
