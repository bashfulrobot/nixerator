{
  config,
  lib,
  pkgs,
  versions,
  ...
}:

let
  cfg = config.apps.cli.kongctl;
  kongctl = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.kongctl.enable = lib.mkEnableOption "kongctl - declarative CLI for Kong Konnect (github.com/Kong/kongctl)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ kongctl ];
  };
}
