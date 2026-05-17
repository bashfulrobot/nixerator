{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.signal-cli;
in
{
  options = {
    apps.cli.signal-cli = {
      enable = lib.mkEnableOption "signal-cli CLI/dbus client for Signal Messenger";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.signal-cli ];
  };
}
