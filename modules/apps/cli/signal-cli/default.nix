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
      enable = lib.mkEnableOption "signal-cli, the command-line/D-Bus client for Signal";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.signal-cli ];
  };
}
