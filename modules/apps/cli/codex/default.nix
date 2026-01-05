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
  options.apps.cli.codex = with lib; {
    enable = mkEnableOption "Codex CLI tool";

    package = mkOption {
      type = types.package;
      default = pkgs.codex;
      defaultText = "pkgs.codex";
      description = "The codex package to use.";
    };

    custom-instructions = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Define custom guidance for the agents; this value is written to ~/.codex/AGENTS.md
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      programs.codex = {
        enable = true;
        inherit (cfg) package custom-instructions;
        settings = null;
      };
    };
  };
}