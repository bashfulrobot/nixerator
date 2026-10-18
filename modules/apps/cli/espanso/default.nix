{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.cli.espanso;
in
{
  options.apps.cli.espanso.enable = lib.mkEnableOption "Espanso text expander (Wayland/Hyprland)";

  config = lib.mkIf cfg.enable {
    # System-level services.espanso, not Home Manager's, because only this
    # one wires up the CAP_DAC_OVERRIDE security wrapper the Wayland worker
    # needs to open /dev/input/*. Home Manager's services.espanso launches
    # the raw, unwrapped pkgs.espanso-wayland store binary and panics with
    # "EVDEV backend is being used, but without enabling linux capabilities"
    # on Hyprland/wlroots -- fixed upstream in nixpkgs#423931 (merged
    # 2025-11-20), but only for this module. Runs as a systemd --user unit
    # (wantedBy graphical-session.target), so it still starts per-session.
    services.espanso = {
      enable = true;
      package = pkgs.espanso-wayland;
      # Lets the Wayland worker detect the focused window (wlr-foreign-toplevel-
      # management protocol) on Hyprland/wlroots, enabling filter_class /
      # filter_title per-app matches. Without it: "wlrctl missing or not
      # available for the current wayland DE" and no app-specific matching.
      #
      # kdotool, wl-clipboard and libnotify are the tools nixpkgs's
      # wrapProgram prefixes onto PATH; the capability wrapper below bypasses
      # that script, so they have to come from the unit's PATH instead.
      extraPackages = [
        pkgs.wlrctl
        pkgs.kdotool
        pkgs.wl-clipboard
        pkgs.libnotify
      ];
    };

    # nixpkgs's services.espanso points security.wrappers.espanso at
    # lib.getExe, which since espanso 2.4.1 is a makeWrapper bash script.
    # NixOS's ensure-wrapper-integrity check refuses non-ELF wrapper targets
    # ("is not an ELF! This is a security risk"), failing the whole system
    # build. makeWrapper keeps the real binary at bin/.espanso-wrapped, so
    # point the capability wrapper there.
    security.wrappers.espanso.source = lib.mkForce "${
      pkgs.espanso-wayland.override { securityWrapperPath = config.security.wrapperDir; }
    }/bin/.espanso-wrapped";

    # Config/match YAML via xdg.configFile (last resort per modules/CLAUDE.md)
    # rather than Home Manager's services.espanso.configs/matches: enabling
    # that module would register a second, conflicting
    # systemd.user.services.espanso alongside the wrapped one above.
    home-manager.users.${globals.user.name} = {
      xdg.configFile = {
        "espanso/config/default.yml".source = ./config/default.yml;
        "espanso/match/base.yml".source = ./match/base.yml;
      };
    };
  };
}
