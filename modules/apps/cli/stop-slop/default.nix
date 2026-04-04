{
  lib,
  pkgs,
  config,
  globals,
  versions,
  ...
}:
let
  cfg = config.apps.cli.stop-slop;
  v = versions.cli.stop-slop;

  stop-slop-src = pkgs.fetchFromGitHub {
    owner = "hardikpandya";
    repo = "stop-slop";
    inherit (v) rev;
    inherit (v) hash;
  };
in
{
  options = {
    apps.cli.stop-slop.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable stop-slop Claude Code skill for detecting AI writing patterns.";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      # Uses home.file to symlink the fetched skill directory into ~/.claude/skills/.
      home.file.".claude/skills/stop-slop" = {
        source = stop-slop-src;
        recursive = true;
      };
    };
  };
}
