{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.suites.ai;
in
{
  options = {
    suites.ai.enable = lib.mkEnableOption "AI suite with assistant and transcription tools";
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
          # Plugins and marketplaces for this host come from the claude-stack
          # manifest snapshot (cfg/claude-stack/<host>.json, see
          # cfg/plugin-config.nix), not from a list here. Edit
          # claude-stack.json in claude-skills to add, drop or pin one. The
          # rationale that used to live in this list (the #294 token-surface
          # audit and the 2026-07-30/31 usage-data drops: learning-output-style,
          # pr-review-toolkit, feature-dev, context7, asana/atlassian/github,
          # code-review, the kotlin/rust LSPs, Kong Skills extras (kong-skills, kong-forge, cs), impeccable,
          # hyperframes, kong-konnect@ai-marketplace, ralph-loop, reap,
          # caveman) is in git history of this file and in
          # .claude/docs/claude-plugins.md. Re-adding any of them needs usage
          # data, not a hunch.
          # Local context-compression CLI (issue #313). Not a plugin -- see
          # cfg/headroom.nix. Workstation-scoped like the rest of this
          # suite; srv's headless list (hosts/srv/modules.nix) deliberately
          # leaves it out, same reasoning as hyperframes: the `[all]` extra
          # is a heavy, workstation-appropriate dependency footprint (ML
          # compressor model, optional torch), not something worth paying
          # for on a headless server.
          headroom.enable = true;
          # Clone + build the binary the kong-docs-rag plugin launches
          # (cfg/kong-docs-rag.nix). qbert snapshot enables the plugin; srv does not.
          kongDocsRag.enable = true;
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
    # (qbert) the same way claude-code and antigravity already do,
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

    # Media toolchain for the dk:video-edit skill (`ve.sh` in claude-skills).
    # The script shells out to `ffmpeg`, `ffprobe` and `whisper-cli`, so the
    # binaries have to be on PATH for every AI-suite host, independent of
    # which Claude Code plugins that host enables.
    #
    # ffmpeg-full is deliberately the same attribute the hyperframes runtime
    # gate installs (modules/apps/cli/claude-code/default.nix). Listing one
    # derivation twice in environment.systemPackages is a no-op, so the two
    # paths share a single closure instead of pulling in a second ffmpeg.
    #
    # whisper-cpp 1.9.5 installs the transcriber as `bin/whisper-cli`
    # (meta.mainProgram, asserted by the package's own installCheckPhase);
    # there is no `bin/whisper-cpp`. Models are not provisioned here -- fetch
    # them with `whisper-cpp-download-ggml-model`, which the same package
    # ships.
    environment.systemPackages = with pkgs; [
      ffmpeg-full
      whisper-cpp
    ];
  };
}
