# Claude desktop app (Electron) — Chat, Cowork, and Claude Code on Linux.
#
# Uses local package from ./build/default.nix (nixpkgs has no derivation).
# Version managed in settings/versions.nix (gui.claude-desktop).
# Docs / updates: https://code.claude.com/docs/en/desktop-linux

{
  lib,
  pkgs,
  config,
  versions,
  globals,
  ...
}:

let
  cfg = config.apps.gui.claude-desktop;
  claudeDesktopPackage = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.gui.claude-desktop.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Claude desktop app (Chat, Cowork, and Claude Code).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      claudeDesktopPackage
    ];

    # Cowork's bundled Linux VM backend probes fixed filesystem paths for its
    # QEMU/OVMF/virtiofsd dependencies -- Anthropic's own error text says
    # "sudo apt install qemu-system-x86 ovmf virtiofsd" -- rather than
    # searching $PATH, so a plain systemPackages install isn't enough on
    # NixOS. This is a detection-only gap, not a real conflict: confirmed
    # against anthropics/claude-code#74605, the probe checks two hardcoded
    # paths for virtiofsd and only falls back to its own bundled copy on
    # Ubuntu 22, so it fails to find a fully working KVM stack on any other
    # distro (NixOS included) even when one is already installed via
    # server.kvm elsewhere on this host. There's no shared daemon, socket, or
    # storage pool between Cowork's VM and libvirtd's -- each just needs its
    # own QEMU binary and /dev/kvm access.
    #
    # OVMF and virtiofsd have documented env-var overrides
    # (CLAUDE_OVMF_CODE_PATH / CLAUDE_VIRTIOFSD_PATH, set on the wrapped
    # binary in ./build), but qemu-system-x86_64 does not -- it must exist at
    # the literal path below. environment.usrbinenv is upstream NixOS's own
    # precedent for exactly this shape of FHS-compat symlink.
    systemd.tmpfiles.rules = [
      "L+ /usr/bin/qemu-system-x86_64 - - - - ${pkgs.qemu_kvm}/bin/qemu-system-x86_64"
    ];

    # /dev/kvm access. Hosts that also enable server.kvm already grant this
    # via its own extraGroups, but Cowork's need for it isn't contingent on
    # that suite, so this module owns it directly. Duplicate "kvm" group
    # entries across modules are harmless -- NixOS merges extraGroups lists.
    users.users.${globals.user.name}.extraGroups = [ "kvm" ];
  };
}
