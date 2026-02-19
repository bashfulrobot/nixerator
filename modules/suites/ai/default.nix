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
      happy.enable = true;
      ollama = {
        enable = true;
        loadModels = [ "glm-5:cloud" ];
      };
      termly.enable = true;
      yepanywhere.enable = true;
    };
  };
}
