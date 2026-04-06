{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.apps.cli.drawio;
in
{
  options.apps.cli.drawio.enable = lib.mkEnableOption "draw.io diagramming tool";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.drawio ];
  };
}
