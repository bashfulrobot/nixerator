{
  globals,
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.apps.cli.pnpm;
in
{
  options = {
    apps.cli.pnpm.enable = lib.mkEnableOption "pnpm -- fast, disk-efficient JavaScript package manager (bundles its own Node.js runtime).";
  };

  config = lib.mkIf cfg.enable {

    home-manager.users.${globals.user.name} = {

      home.packages = [
        pkgs.pnpm
      ];

    };

  };
}
