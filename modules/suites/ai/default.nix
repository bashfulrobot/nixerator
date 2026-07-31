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
          #   asana, atlassian, github -- their MCP servers sat unauthenticated
          #     in `/mcp` with zero real use (github work goes through the `gh`
          #     CLI, not this MCP). Dropped 2026-07-27; re-add with usage data.
          #   code-review, kotlin-lsp, rust-analyzer-lsp, kong-skills, kong-skill,
          #     commit@kong-skills, feature-request@kong-skills, impeccable,
          #     hyperframes, kong-konnect@ai-marketplace -- zero pluginUsage and
          #     zero transcript hits over 50 sessions / 3.5 days (claude-code
          #     doctor, 2026-07-30). code-review/commit@kong-skills/
          #     feature-request@kong-skills were shadowed by the personal
          #     review-dev, review-security, commit, and feature-request skills
          #     the whole time. kotlin-lsp/rust-analyzer-lsp: no Kotlin/Rust
          #     project has touched this user-scope install; re-add if one does.
          #     kong-konnect@ai-marketplace (20 Konnect skills): zero use despite
          #     being Kong's own product -- its bundled MCP server was already
          #     shadowed (see the old comment this replaced), the skills just
          #     never got invoked either. Dropped 2026-07-30; re-add with usage
          #     data, same bar as everything else here.
          #   ralph-loop, reap (cfg/reap.nix + build/reap) -- dropped 2026-07-31.
          #     Both are "run autonomously until goal" engines, same job as the
          #     `auto` skill. Intent-log scan across 596 sessions: `/auto` in 18
          #     sessions, `reap.` in 2, `ralph-loop` in 1 -- `auto` is the one
          #     actually used, and it already has the sentinel-gated rm/kill/pkill
          #     PreToolUse wiring (cfg/scripts/auto-gate.sh) the others lack.
          #     clay-ralph (a user skill, unmanaged by Nix) was the fourth such
          #     engine and was removed directly from ~/.claude/skills/ for the
          #     same reason (1 session hit).
          #   caveman -- dropped 2026-07-31. Its SessionStart/UserPromptSubmit
          #     ruleset directly contradicted ~/.claude/CLAUDE.md's non-negotiable
          #     "run all prose through humanizer" hard rule (the plugin's own
          #     docs admitted the clash and required a manual per-repo/per-session
          #     drop-out). Removed at the root rather than scoped, per a full
          #     setup review; see git history (.claude/docs/caveman.md, this
          #     file's blame) if it comes back.
          # Re-adding any of these should come with usage data, not a hunch.
          plugins = [
            # claude-plugins-official (built-in marketplace)
            "frontend-design@claude-plugins-official"
            "commit-commands@claude-plugins-official"
            "security-guidance@claude-plugins-official"
            "slack@claude-plugins-official"
            "skill-creator@claude-plugins-official"
            "gopls-lsp@claude-plugins-official"
            "pyright-lsp@claude-plugins-official"
            # kong-skills (Kong CS marketplace, SHA-pinned)
            "kong-doc-build@kong-skills"
            # other third-party (SHA-pinned)
            # Context-window auditing. Unlike the plugins struck from this list
            # under #294, its standing cost (4 skills, 2 commands) buys a
            # measurement of exactly the thing that audit was about. Needs the
            # NixOS plumbing in cfg/token-optimizer.nix to run at all, and
            # carries a noncommercial-only licence -- read
            # .claude/docs/token-optimizer.md before putting it on a work host.
            "token-optimizer@alexgreensh-token-optimizer"
            # Semantic change-summary cards (issue #303). See
            # cfg/plugin-config.nix for why it's trusted. The Stop hook has no
            # browser/GPU dependency, unlike hyperframes above, so nothing
            # here would stop it working headless; it's simply not part of
            # srv's own curated minimal list (hosts/srv/modules.nix), the same
            # reason that list omits the kong CS tooling and some LSPs.
            "semagraph@semagraph"
          ];
          # Local context-compression CLI (issue #313). Not a plugin -- see
          # cfg/headroom.nix. Workstation-scoped like the rest of this
          # suite; srv's headless list (hosts/srv/modules.nix) deliberately
          # leaves it out, same reasoning as hyperframes: the `[all]` extra
          # is a heavy, workstation-appropriate dependency footprint (ML
          # compressor model, optional torch), not something worth paying
          # for on a headless server.
          headroom.enable = true;
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
