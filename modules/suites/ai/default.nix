{
  lib,
  config,
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
          #
          # Deliberately absent (see issue #294, a token-surface audit over 90
          # days of transcripts). Every plugin here costs standing context on
          # every turn, so a plugin that ships agents or an output style has to
          # earn it:
          #   learning-output-style -- injects a system-prompt block telling
          #     Claude to stop and hand TODOs back for the user to write. The
          #     opposite of what's wanted, and it inflates turn count.
          #   pr-review-toolkit     -- six agent definitions (~1.8k tokens
          #     resident), dispatched once ever. review-dev/review-security
          #     cover this via the local reviewer-* agents.
          #   feature-dev           -- three agent definitions, never dispatched.
          #   context7              -- duplicate mount. The user-scoped server in
          #     cfg/mcp-servers.nix is the single source; the plugin only added a
          #     second copy of the same tool schemas.
          # Re-adding any of these should come with usage data, not a hunch.
          plugins = [
            # claude-plugins-official (built-in marketplace)
            "frontend-design@claude-plugins-official"
            "asana@claude-plugins-official"
            "code-review@claude-plugins-official"
            "github@claude-plugins-official"
            "commit-commands@claude-plugins-official"
            "security-guidance@claude-plugins-official"
            "atlassian@claude-plugins-official"
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
            # Context-window auditing. Unlike the plugins struck from this list
            # under #294, its standing cost (4 skills, 2 commands) buys a
            # measurement of exactly the thing that audit was about. Needs the
            # NixOS plumbing in cfg/token-optimizer.nix to run at all, and
            # carries a noncommercial-only licence -- read
            # .claude/docs/token-optimizer.md before putting it on a work host.
            "token-optimizer@alexgreensh-token-optimizer"
          ];
        };
        antigravity.enable = true;
        superpowers.enable = true;
        skillfish.enable = true;
        skill-cache.enable = true;
      };
    };

    # opencode, the CLI agent harness for driving local (Ollama) or cloud
    # models (opencode from the llm-agents input, the same source as
    # claude-code). Provider-agnostic, so it rides along on every AI-suite host
    # (qbert, donkeykong) the same way claude-code and antigravity already do,
    # usable against cloud models without any local server. Only the local
    # Ollama server and the opencode provider/model wiring that points at it are
    # qbert-only (they need the GPU, see hosts/qbert and the ollama module);
    # opencode itself is general.
    #
    # opencode acts with the user's privileges: it runs model-directed shell
    # commands, so any model it is pointed at is a code-execution path, not just
    # a text source. The local model is an unpinned pull (see the trust note on
    # apps.cli.ollama.loadModels).
    #
    # Delivered by the dedicated apps.cli.opencode module: it installs the
    # package, wires the LSP language servers, and lets the ollama module
    # contribute its local-provider settings to opencode.json.
    apps.cli.opencode.enable = true;
  };
}
