{
  hostname,
  globals,
  inputs,
  pkgs,
  ...
}:

let
  voxtypePkgs = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system};

  # voxtype's unwrapped Vulkan build fails to link on the 2026-11-11 nixpkgs
  # (`cannot find -lsqlite3`): nixpkgs stopped supplying sqlite to it
  # implicitly. Rebuild the unwrapped package with sqlite and keep upstream's
  # wrapper (which puts wtype, wl-clipboard and the rest on PATH) by swapping
  # only the wrapper's `paths`. Remove once upstream voxtype builds on current
  # nixpkgs without this.
  voxtypeVulkan = voxtypePkgs.vulkan.overrideAttrs (_old: {
    paths = [
      (voxtypePkgs.voxtype-vulkan-unwrapped.overrideAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.sqlite ];
      }))
    ];
  });
in
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
  # `acceleration` option picks the vulkan variant, and `package` swaps in the
  # sqlite-patched build from the let block above. VAD is on by the module default, which fixes the
  # occasional "dictated X, typed unrelated Y" whisper-hallucination-on-silence.
  hyprflake.desktop.voxtype = {
    #model = "large-v3-turbo";
    #model = "base.en";
    model = "small.en";
    threads = 16;
    acceleration = "vulkan";
    package = voxtypeVulkan;
  };

  # Enable archetypes
  archetypes.workstation.enable = true;
}
