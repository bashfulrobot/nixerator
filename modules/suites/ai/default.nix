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

    apps.webapps = {
      clay.enable = true;
      claude.enable = true;
    };

    apps.cli = {
      agent-scan.enable = true;
      agentos.enable = true;
      clay.enable = true;
      drawio.enable = true;
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
          "hyperframes@hyperframes"
        ];
      };
      claude-remote = {
        enable = true;
        controlTower.enable = true;
      };
      gemini-cli.enable = true;
      # llmfit: removed
      plannotator.enable = true;

      crawl4ai.enable = true;
      claw-ide = {
        enable = true;
        service.enable = true;
      };
      dorkos = {
        enable = false;
        service.enable = true;
      };
      superpowers.enable = true;
      # Disabled: upstream paseo (v0.1.72..v0.1.74) ships an npm-deps FOD hash
      # that no longer matches what fetchNpmDeps produces, blocking every
      # nixerator rebuild. Re-enable once getpaseo/paseo cuts a release whose
      # npmDepsHash is correct against the current registry.
      paseo.enable = false;
      skillfish.enable = true;
      ollama = {
        enable = false;
        loadModels = [ "glm-5:cloud" ];
      };
    };

    # system.moshi: disabled
  };
}
