{
  globals,
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.ollama;
  accelerationPackages = {
    cpu = pkgs.ollama-cpu;
    cuda = pkgs.ollama-cuda;
    rocm = pkgs.ollama-rocm;
    vulkan = pkgs.ollama-vulkan;
  };
  selectedPackage =
    if cfg.acceleration == null then pkgs.ollama else accelerationPackages.${cfg.acceleration};
  endpoint = "${cfg.host}:${toString cfg.port}";
in
{
  options = {
    apps.cli.ollama = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Ollama local LLM server.";
      };

      acceleration = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "cpu"
            "cuda"
            "rocm"
            "vulkan"
          ]
        );
        default = null;
        description = "Select the Ollama acceleration backend (null uses default package).";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address the Ollama server listens on (loopback by default).";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 11434;
        description = "Port the Ollama server listens on.";
      };

      loadModels = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Models to prefetch and load at service start. Registry names
          (e.g. "llama3.2") and HuggingFace GGUF pulls
          (e.g. "hf.co/JetBrains/Mellum2-12B-A2.5B-Thinking-GGUF-Q4_K_M")
          are both accepted, since each entry is passed to `ollama pull`.

          The pull runs from a post-start unit, so on first activation with the
          network down or HuggingFace throttling, the model is absent until the
          next successful pull and clients report model-not-found. If a client
          cannot find the model, check `ollama list` and re-pull before
          assuming the client is misconfigured.

          Each entry is a mutable reference (a registry name or an `hf.co`
          repo/tag), not a content-pinned artifact, and `ollama pull` fetches it
          over the network at service start. The Nix flake pin does not cover
          this fetch: a tag re-upload or an upstream compromise lands the new
          bytes on the next activation unreviewed, and the daemon parses
          whatever it receives. Only list models from sources trusted to the
          same level as code that runs on the host, since a local model here
          drives goose (shell) and aider (file edits). For stronger integrity,
          vendor the GGUF with a pinned hash and register it via `ollama create`
          rather than pulling a tag.
        '';
      };

      exportClientEnv = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Export OLLAMA_HOST and OLLAMA_API_BASE into the user's session so
          Ollama clients (the ollama CLI, goose, aider, any OpenAI-compatible
          tool) resolve this local server without per-invocation flags.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Ollama ships no authentication, so a non-loopback bind publishes an open
    # inference API (read prompts, run inference, pull models to fill the disk,
    # plus any RCE in its HTTP surface) to everyone who can reach it. Nothing
    # here opens the firewall, but surface a build-time warning when host leaves
    # loopback so the exposure is a deliberate choice, not a silent default.
    # (warnings, not lib.warnIf around config, or the config key set would
    # depend on cfg.host and the module fixpoint recurses infinitely.)
    warnings =
      lib.optional
        (
          !lib.elem cfg.host [
            "127.0.0.1"
            "::1"
            "localhost"
          ]
        )
        "apps.cli.ollama: host = ${cfg.host} is not loopback and Ollama has no auth; anyone able to reach ${endpoint} can use and abuse it. Restrict access (firewall or tailnet ACL) before exposing it.";

    environment.systemPackages = [ selectedPackage ];

    services.ollama = {
      enable = true;
      package = selectedPackage;
      inherit (cfg) host port loadModels;
    };

    home-manager.users.${globals.user.name} = lib.mkIf cfg.exportClientEnv {
      # Both variables carry the full URL scheme. goose's provider docs set
      # OLLAMA_HOST as http://host:port (not a bare host:port), and the ollama
      # CLI accepts the scheme form too; OLLAMA_API_BASE is aider's convention.
      # Both point at the same local server so clients need no endpoint flags.
      home.sessionVariables = {
        OLLAMA_HOST = "http://${endpoint}";
        OLLAMA_API_BASE = "http://${endpoint}";
      };

      # Convenience alias so the aider invocation against the local model is not
      # something to memorise. goose reads GOOSE_MODEL and needs no flag; aider
      # takes the model on the command line, where ollama_chat/<name> is aider's
      # documented Ollama routing and OLLAMA_API_BASE above points it at this
      # server. The model is globals.ai.localCodeModel, the same single source
      # the server pull and GOOSE_MODEL read, so the alias cannot drift from the
      # pulled model. Gated on fish, so it is a no-op on hosts without it.
      programs.fish.shellAliases = lib.mkIf config.apps.cli.fish.enable {
        aider-local = "aider --model ollama_chat/${globals.ai.localCodeModel}";
      };
    };
  };
}
