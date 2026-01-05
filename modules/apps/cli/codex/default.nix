{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.codex;
  tomlFormat = pkgs.formats.toml { };
in
{
  options.programs.codex = with lib; {
    enable = mkEnableOption "Codex";

    package = mkOption {
      type = types.package;
      default = pkgs.codex;
      defaultText = "pkgs.codex";
      description = "The codex package to use.";
    };

    settings = mkOption {
      type = with types; nullOr (submodule {
        freeformType = tomlFormat.type;
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
    home.packages = [ cfg.package ];

    home.file.".codex/config.toml" = lib.mkIf (cfg.settings != null) {
      source = tomlFormat.generate "codex-config.toml" cfg.settings;
    };

    home.file.".codex/AGENTS.md" = lib.mkIf (cfg.custom-instructions != "") {
      text = cfg.custom-instructions;
    };
  };
}
