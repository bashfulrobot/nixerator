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
      clay.enable = true;
      claude-code = {
        enable = true;
        plugins = [
          "frontend-design@claude-plugins-official"
          "asana@claude-plugins-official"
          "code-review@claude-plugins-official"
          "context7@claude-plugins-official"
          "github@claude-plugins-official"
          "feature-dev@claude-plugins-official"
          "commit-commands@claude-plugins-official"
          "security-guidance@claude-plugins-official"
          "pr-review-toolkit@claude-plugins-official"
          "atlassian@claude-plugins-official"
          "learning-output-style@claude-plugins-official"
          "slack@claude-plugins-official"
          "gopls-lsp@claude-plugins-official"
          "skill-creator@claude-plugins-official"
          "ralph-loop@claude-plugins-official"
        ];
      };
      gemini-cli.enable = true;
      # termly: disabled
      # llmfit: removed
      plannotator.enable = true;
      sled.enable = true;
      stop-slop.enable = true;
      superpowers.enable = true;
      paseo.enable = true;
      ollama = {
        enable = false;
        loadModels = [ "glm-5:cloud" ];
      };
    };

    system.moshi.enable = true;
  };
}
