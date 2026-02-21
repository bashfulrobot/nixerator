{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.termly;
  termlyCli = pkgs.callPackage ./build { };
in
{
  options = {
    apps.cli.termly = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Termly CLI.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ termlyCli ];
  };
}
