{
  hostname,
  globals,
  ...
}:

{
  # Import hardware configuration
  imports = [
    ./hardware-configuration.nix # Hardware-specific settings (generated with --no-filesystems)
    ./disko.nix # Disko declarative disk partitioning
    ./boot.nix # Bootloader configuration
    ./gpu.nix # AMD GPU configuration
    ./power-management.nix # Power management workarounds for AMD GPU suspend and USB wakeup
    ./reboot-windows.nix # Desktop entry for rebooting to Windows
    ./modules.nix # Module configuration
    # Auto-import all modules
    ../../modules
  ];

  # Networking
  networking = {
    hostName = hostname;
    interfaces.enp34s0.wakeOnLan.enable = true;
    firewall.allowedTCPPorts = [
      5173 # Upsight UI previews
    ];
  };

  # Localization (from globals)
  # Note: timezone is managed by services.automatic-timezoned (enabled in core suite)
  i18n.defaultLocale = globals.defaults.locale;

  # Voxtype on qbert: Vulkan on the AMD 6800 XT, thread cap kept. The module's
  # `acceleration` option picks the vulkan variant, so no manual package
  # override is needed. VAD is on by the module default, which fixes the
  # occasional "dictated X, typed unrelated Y" whisper-hallucination-on-silence.
  hyprflake.desktop.voxtype = {
    #model = "large-v3-turbo";
    #model = "base.en";
    model = "small.en";
    threads = 16;
    acceleration = "vulkan";
  };

  # Enable archetypes
  archetypes.workstation.enable = true;
}
