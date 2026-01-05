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

    settings = mkOption {
      type = with types; nullOr (submodule {
        freeformType = pkgs.formats.toml { }.type;
        options = { };
      });
      default = { };
      description = ''
        Configuration written to ~/.codex/config.toml.
        See <https://github.com/openai/codex-rs/blob/main/doc/config.md> for supported values.
      '';
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
        inherit (cfg) package settings custom-instructions;
      };
    };
  };
}
