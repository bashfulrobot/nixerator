{
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.cli.jwtx;
  jwtx = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.jwtx.enable = lib.mkEnableOption "jwtx terminal JWT decoder/encoder TUI";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ jwtx ];
  };
}
