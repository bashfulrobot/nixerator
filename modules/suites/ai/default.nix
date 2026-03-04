{ lib, config, ... }:

let
  cfg = config.suites.ai;
in
{
  options = {
    suites.ai.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable AI suite with assistant and transcription tools.";
    };
  };

  config = lib.mkIf cfg.enable {
    apps.gui = {
    };

    apps.cli = {
      claude-code.enable = true;
      gemini-cli.enable = true;
      happy-coder.enable = true;
      yepanywhere.enable = true;
      ollama = {
        enable = false;
        loadModels = [ "glm-5:cloud" ];
      };
    };
  };
}
