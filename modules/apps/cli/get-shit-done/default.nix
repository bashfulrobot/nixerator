{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.cli.get-shit-done;
  username = globals.user.name;

  # Fetch the get-shit-done repository
  gsdSrc = pkgs.fetchFromGitHub {
    owner = "glittercowboy";
    repo = "get-shit-done";
    rev = "83845755b318aeacaac7d24c380a0e8f273046ef";
    hash = "sha256-px807WLNIKl39YDfCBs9w8jq7w3dPO9BTJlA5hHu74U=";
  };
in
{
  options = {
    apps.cli.get-shit-done = {
      enable = lib.mkEnableOption "Get Shit Done (GSD) commands for Claude Code";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      # Install GSD commands to ~/.claude/commands/gsd/
      home.file.".claude/commands/gsd" = {
        source = "${gsdSrc}/commands/gsd";
        recursive = true;
      };
    };
  };
}
