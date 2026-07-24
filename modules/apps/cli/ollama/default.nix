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
          drives opencode, an agent with shell access. For stronger integrity,
          vendor the GGUF with a pinned hash and register it via `ollama create`
          rather than pulling a tag.
        '';
      };

      exportClientEnv = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Export OLLAMA_HOST so the ollama CLI (and any OpenAI-compatible
          client) reaches this local server without per-invocation flags.

          Delivered through fish shellInit, not home.sessionVariables. This
          host's fish does not source hm-session-vars, so home.sessionVariables
          never reach the shell or its child processes (see the same reasoning
          for the token exports in modules/apps/cli/fish). Gated on the fish
          module, so it is a no-op where fish is not enabled.

          opencode does not read OLLAMA_HOST; it is pointed at the server
          through defaultOpencodeModel's provider config instead.
        '';
      };

      defaultOpencodeModel = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "qwen3:14b";
        description = ''
          When set, register the local Ollama server as an OpenAI-compatible
          provider in opencode and default opencode to this model, so `opencode`
          runs against the local server with no manual provider setup. Written
          to ~/.config/opencode/opencode.json via programs.opencode.settings
          (the opencode home-manager module, enabled by suites.ai); the
          top-level model becomes `ollama/<model>`.

          Set this to a model that loadModels actually pulls, or opencode
          reports model-not-found. null leaves opencode with no local provider
          (it uses whatever providers are otherwise configured).
        '';
      };

      contextLength = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        example = 32768;
        description = ''
          Default context window in tokens for served models, set via
          OLLAMA_CONTEXT_LENGTH. Ollama's own default is only a few thousand
          tokens, which silently truncates long opencode sessions well before a
          model's real limit. null leaves ollama's default.

          The practical ceiling is VRAM, since the KV cache grows with the
          context length. On a 16 GB card a ~12B Q4_K_M model holds roughly 32k
          tokens with a full-precision (f16) KV cache. To go higher, enable
          flashAttention and set kvCacheType to q8_0 so the KV cache is smaller.
        '';
      };

      flashAttention = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable flash attention (OLLAMA_FLASH_ATTENTION=1). A mathematically
          equivalent attention implementation with a smaller, faster KV cache,
          so a larger contextLength fits in the same VRAM at no quality cost.
          Also required before kvCacheType can quantize the KV cache.
        '';
      };

      kvCacheType = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "f16"
            "q8_0"
            "q4_0"
          ]
        );
        default = null;
        description = ''
          KV cache quantization, set via OLLAMA_KV_CACHE_TYPE. null (ollama's
          f16 default) is full precision. q8_0 roughly halves KV memory for a
          small quality cost and is the usual pick to reach 64k+ on a 16 GB
          card; q4_0 is smaller again but noticeably more lossy. Requires
          flashAttention.
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

    # ollama only quantizes the KV cache when flash attention is on, so a
    # kvCacheType without flashAttention would silently do nothing.
    assertions = [
      {
        assertion = cfg.kvCacheType == null || cfg.flashAttention;
        message = "apps.cli.ollama.kvCacheType requires flashAttention = true (ollama only quantizes the KV cache with flash attention enabled).";
      }
    ];

    environment.systemPackages = [ selectedPackage ];

    services.ollama = {
      enable = true;
      package = selectedPackage;
      inherit (cfg) host port loadModels;
      # Server-side model runtime knobs. Empty unless the host opts in, so this
      # does not disturb ollama's defaults when the options are left null/false.
      environmentVariables =
        (lib.optionalAttrs (cfg.contextLength != null) {
          OLLAMA_CONTEXT_LENGTH = toString cfg.contextLength;
        })
        // (lib.optionalAttrs cfg.flashAttention {
          OLLAMA_FLASH_ATTENTION = "1";
        })
        // (lib.optionalAttrs (cfg.kvCacheType != null) {
          OLLAMA_KV_CACHE_TYPE = cfg.kvCacheType;
        });
    };

    home-manager.users.${globals.user.name} = lib.mkMerge [
      # Point the ollama CLI (and any OpenAI-compatible client) at the local
      # server. Delivered via fish shellInit, not home.sessionVariables: this
      # host's fish does not source hm-session-vars, so home.sessionVariables
      # never reach the shell or its children. shellInit is the repo's proven
      # mechanism for env vars in fish (see the token exports in the fish
      # module). OLLAMA_HOST carries the scheme, which the ollama CLI accepts.
      (lib.mkIf (cfg.exportClientEnv && config.apps.cli.fish.enable) {
        programs.fish.shellInit = ''
          set -gx OLLAMA_HOST "http://${endpoint}"
        '';
      })

      # Register the local ollama server as an OpenAI-compatible provider in
      # opencode and default opencode to the local model, so `opencode` needs no
      # manual provider setup. opencode reads this from
      # ~/.config/opencode/opencode.json, written by programs.opencode (enabled
      # by suites.ai). ollama exposes an OpenAI-compatible API under /v1, which
      # the @ai-sdk/openai-compatible provider targets; the top-level model is
      # prefixed with the provider id (`ollama/<model>`).
      (lib.mkIf (cfg.defaultOpencodeModel != null) {
        programs.opencode.settings = {
          model = "ollama/${cfg.defaultOpencodeModel}";
          provider.ollama = {
            npm = "@ai-sdk/openai-compatible";
            name = "Ollama (local)";
            options.baseURL = "http://${endpoint}/v1";
            models.${cfg.defaultOpencodeModel} = { };
          };
        };
      })
    ];
  };
}
