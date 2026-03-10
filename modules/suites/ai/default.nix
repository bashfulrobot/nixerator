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
      termly = {
        enable = true;
        remote = {
          enable = true;
          directories = [
            "/home/dustin/dev/nix/nixerator"
            "/home/dustin/dev/nix/hyprflake"
            "/home/dustin/dev/go/meetsum"
            "/home/dustin/dev/go/mcp-tool-proxy"
            "/home/dustin/dev/kong/lab"
            "/home/dustin/dev/kong/scratch"
            "/home/dustin/dev/infra"
          ];
        };
      };
      ollama = {
        enable = false;
        loadModels = [ "glm-5:cloud" ];
      };
    };
  };
}
