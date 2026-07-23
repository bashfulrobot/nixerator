{
  lib,
  config,
  pkgs,
  globals,
  ...
}:

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
    apps = {
      gui = {
        claude-desktop.enable = true;
      };

      cli = {
        agent-scan.enable = true;
        agentos.enable = true;
        claude-code = {
          enable = true;
          # Workstation plugin set. Drives the declarative, SHA-pinned
          # settings.json overlay (cfg/plugin-config.nix) -- each id is enabled
          # and its marketplace registered + pinned. superpowers is added by the
          # superpowers module. Headless srv keeps a smaller list in
          # hosts/srv/modules.nix (no browser-dependent hyperframes, no kong CS
          # tooling, fewer LSPs).
          plugins = [
            # claude-plugins-official (built-in marketplace)
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
            "skill-creator@claude-plugins-official"
            "ralph-loop@claude-plugins-official"
            "gopls-lsp@claude-plugins-official"
            "kotlin-lsp@claude-plugins-official"
            "pyright-lsp@claude-plugins-official"
            "rust-analyzer-lsp@claude-plugins-official"
            # kong-skills (Kong CS marketplace, SHA-pinned)
            "kong-skills@kong-skills"
            "kong-skill@kong-skills"
            "commit@kong-skills"
            "feature-request@kong-skills"
            "kong-doc-build@kong-skills"
            # ai-marketplace (Kong's public skills hub, SHA-pinned). One plugin,
            # 20 Konnect skills. It also bundles an MCP server named
            # `kong-konnect`, which is shadowed by the identically-named
            # user-scoped server in cfg/mcp-servers.nix -- user scope outranks
            # plugin scope, so the 1Password-injected PAT keeps winning over the
            # plugin's ${KONNECT_TOKEN} placeholder.
            "kong-konnect@ai-marketplace"
            # other third-party (SHA-pinned)
            "impeccable@impeccable"
            "hyperframes@hyperframes"
          ];
        };
        gemini-cli.enable = true;
        superpowers.enable = true;
        skillfish.enable = true;
        skill-cache.enable = true;
      };
    };

    # CLI agent harnesses for driving local (Ollama) or cloud models. goose is
    # the general tool-using agent (goose-cli from the llm-agents input, the
    # same source as claude-code); aider is the edit-format coding driver that
    # does not depend on model-native tool-calling, so it stays reliable
    # against a small local model.
    #
    # These are provider-agnostic, so they ride along on every AI-suite host
    # (qbert, donkeykong) the same way claude-code and gemini-cli already do,
    # usable against cloud models without any local server. This is deliberate:
    # only the local Ollama server and its default model are qbert-only (they
    # need the GPU, see hosts/qbert), the agent CLIs themselves are general.
    home-manager.users.${globals.user.name}.home.packages = [
      pkgs.llm-agents.goose-cli
      pkgs.aider-chat
    ];
  };
}
