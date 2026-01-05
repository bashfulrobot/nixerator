{
  config,
  lib,
  pkgs,
  globals,
  ...
}:
let
  cfg = config.apps.cli.codex;
  username = globals.user.name;
in
{
  options = { # Changed from options.apps.cli.codex = {
    apps.cli.codex = {
      enable = lib.mkEnableOption "Codex CLI tool";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      programs.codex.enable = true;
    };
  };
}
