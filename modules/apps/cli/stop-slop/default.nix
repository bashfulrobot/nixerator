{
  lib,
  pkgs,
  config,
  globals,
  ...
}:
let
  cfg = config.apps.cli.stop-slop;

  stop-slop-src = pkgs.fetchFromGitHub {
    owner = "hardikpandya";
    repo = "stop-slop";
    rev = "65d52b35d7243427ac646e83eae5a9b0709aa191";
    hash = "sha256-NcwN37kSKOO+4QIhIEVafFtg15KCufmxTJiX3AGQRh0=";
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
      # Uses home.file directly (matching what programs.claude-code.skills
      # does internally for directory paths) because fetchFromGitHub returns
      # a derivation, not a Nix path literal that lib.types.path requires.
      home.file.".claude/skills/stop-slop" = {
        source = stop-slop-src;
        recursive = true;
      };
    };
  };
}
