{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.apps.cli.dank-unstick;

  dank-unstick = pkgs.writeShellApplication {
    name = "dank-unstick";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./scripts/dank-unstick.sh;
  };
in
{
  options.apps.cli.dank-unstick.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Install `dank-unstick`: a recovery command for Hyprland's "lockscreen
      died" black-screen fallback, where DMS's quickshell lock client
      crashes while the session is locked and Hyprland blacks the screen
      until a live client completes a proper lock/unlock handshake. Forces
      that handshake via `dms ipc call lock ...`, so it can be run headless
      over SSH without touching the graphical session.
    '';
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ dank-unstick ];
  };
}
