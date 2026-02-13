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
      whispering.enable = true;
    };

    apps.cli.ollama = {
      enable = true;
      loadModels = [ "glm-5:cloud" ];
    };
  };
}
