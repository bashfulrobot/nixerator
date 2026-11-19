{
  hostname,
  globals,
  inputs,
  pkgs,
  ...
}:

let
  voxtypePkgs = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system};

  # voxtype's unwrapped Vulkan build fails to link (`cannot find -lsqlite3`).
  # The rustc link line asks for a bare `-lsqlite3` that nothing on the build
  # inputs satisfies, even though Cargo.toml declares `rusqlite` with the
  # `bundled` feature (UNVERIFIED: libsqlite3-sys presumably takes its
  # system-link path rather than compiling the vendored amalgamation). Rebuild
  # the unwrapped package with sqlite and keep upstream's wrapper (which puts
  # wtype, wl-clipboard and the rest on PATH) by swapping only the wrapper's
  # `paths`.
  #
  # Still required as of 2026-11-19 on nixpkgs d5cc683 (2026-11-13). Verified
  # by building `voxtype-vulkan-unwrapped` without this override: it fails with
  # the same error on both the locked voxtype fbedd62 (1.2.1) and upstream HEAD
  # 96a4277 (1.2.2, 2026-11-17). voxtype's flake.nix supplies sqlite to no
  # variant, so an upstream fix is warranted. Re-test on the next nixpkgs or
  # voxtype bump and drop this once the unwrapped build links on its own.
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
