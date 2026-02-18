{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.termly;
  termlyPackage = "@termly-dev/cli@${cfg.version}";
  termly = pkgs.writeShellScriptBin "termly" ''
    exec ${pkgs.nodejs_24}/bin/npm exec --yes --package "${termlyPackage}" -- termly "$@"
  '';
in
{
  options = {
    apps.cli.termly = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Termly CLI (installed via npm).";
      };

      version = lib.mkOption {
        type = lib.types.str;
        default = "latest";
        description = "npm version for @termly-dev/cli (default: latest).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ termly ];
  };
}

