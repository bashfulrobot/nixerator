{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.yepanywhere;
  yepanywherePackage = "yepanywhere@${cfg.version}";
  yepanywhere = pkgs.writeShellScriptBin "yepanywhere" ''
    exec ${pkgs.nodejs_24}/bin/npm exec --yes --package "${yepanywherePackage}" -- yepanywhere "$@"
  '';
in
{
  options = {
    apps.cli.yepanywhere = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable yepanywhere CLI (installed via npm).";
      };

      version = lib.mkOption {
        type = lib.types.str;
        default = "latest";
        description = "npm version for yepanywhere (default: latest).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ yepanywhere ];
  };
}
