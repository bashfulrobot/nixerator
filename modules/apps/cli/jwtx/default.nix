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
    apps.cli.jwtx.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable jwtx terminal JWT decoder/encoder TUI.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ jwtx ];
  };
}
