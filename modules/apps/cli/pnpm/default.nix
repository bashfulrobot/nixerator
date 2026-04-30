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
    apps.cli.pnpm.enable = lib.mkEnableOption "pnpm -- fast, disk-efficient JavaScript package manager. Also installs nodejs because pnpm's bundled node is internal-only -- scripts in node_modules/.bin/ have a `#!/usr/bin/env node` shebang that needs node on PATH.";
  };

  config = lib.mkIf cfg.enable {

    home-manager.users.${globals.user.name} = {

      home.packages = [
        pkgs.pnpm
        pkgs.nodejs
      ];

    };

  };
}
