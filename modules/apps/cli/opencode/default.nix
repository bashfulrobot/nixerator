{
  globals,
  lib,
  pkgs,
  config,
  versions,
  ...
}:

let
  cfg = config.apps.cli.opencode;

  # Reuse the same locally built language servers Zed and Helix pin, so the
  # kotlin/yaml tooling matches across all three editors.
  kotlin-lsp = pkgs.callPackage ../kotlin-lsp/build { inherit versions; };
  yaml-schema-router = pkgs.callPackage ../yaml-schema-router/build { inherit versions; };

  # Curated, agent-focused LSP set. Each server is pinned to its exact Nix
  # store binary (like the Zed/Helix modules) and given the file extensions
  # opencode should launch it for. opencode reads this from the `lsp` key of
  # ~/.config/opencode/opencode.json, written via programs.opencode.settings.
  # Launch subcommands (`serve`, `lsp stdio`, `start`, `server`, `--stdio`)
  # were confirmed against each binary's --help.
  lspServers = {
    nixd = {
      command = [ "${pkgs.nixd}/bin/nixd" ];
      extensions = [ ".nix" ];
    };
    gopls = {
      command = [ "${pkgs.gopls}/bin/gopls" ];
      extensions = [ ".go" ];
    };
    golangci-lint-langserver = {
      command = [ "${pkgs.golangci-lint-langserver}/bin/golangci-lint-langserver" ];
      extensions = [ ".go" ];
    };
    rust-analyzer = {
      command = [ "${pkgs.rust-analyzer}/bin/rust-analyzer" ];
      extensions = [ ".rs" ];
    };
    terraform-ls = {
      command = [
        "${pkgs.terraform-ls}/bin/terraform-ls"
        "serve"
      ];
      extensions = [
        ".tf"
        ".tfvars"
      ];
    };
    taplo = {
      command = [
        "${pkgs.taplo}/bin/taplo"
        "lsp"
        "stdio"
      ];
      extensions = [ ".toml" ];
    };
    # yaml-language-server fronted by the schema-router wrapper, matching the
    # Zed/Helix wiring (the router injects the right schema per document).
    yaml = {
      command = [
        "${yaml-schema-router}/bin/yaml-schema-router"
        "--lsp-path"
        "${pkgs.yaml-language-server}/bin/yaml-language-server"
      ];
      extensions = [
        ".yaml"
        ".yml"
      ];
    };
    bash = {
      command = [
        "${pkgs.bash-language-server}/bin/bash-language-server"
        "start"
      ];
      extensions = [
        ".sh"
        ".bash"
      ];
    };
    marksman = {
      command = [
        "${pkgs.marksman}/bin/marksman"
        "server"
      ];
      extensions = [
        ".md"
        ".markdown"
      ];
    };
    # Prose/grammar checking with the same Canadian dialect Zed/Helix set. The
    # dialect is not a CLI flag; harper-ls reads it from initializationOptions.
    harper-ls = {
      command = [
        "${pkgs.harper}/bin/harper-ls"
        "--stdio"
      ];
      extensions = [
        ".md"
        ".markdown"
      ];
      initialization.harper-ls.dialect = "Canadian";
    };
    kotlin-lsp = {
      command = [ "${kotlin-lsp}/bin/kotlin-lsp" ];
      extensions = [
        ".kt"
        ".kts"
      ];
    };
  };

  # opencode permission rules. Each rule resolves to allow, ask or deny, and the
  # LAST matching pattern in an object wins. home-manager serialises the
  # settings with attribute names sorted, so every object below is written as a
  # "*" catch-all (which sorts first) plus narrower patterns that sort after it
  # and therefore override it. Keep new patterns in that shape.
  allowAll = patterns: lib.genAttrs patterns (_: "allow");
  denyAll = patterns: lib.genAttrs patterns (_: "deny");

  # Read-only inspection that runs without a prompt, for system-wide
  # troubleshooting. Anything not listed here (sudo, systemctl restart,
  # nixos-rebuild, rm, just, find, curl) falls through to the "*" ask rule, so a
  # system-wide fix needs approval. Deliberately absent: cat, grep and tail,
  # which would read ~/.ssh and the secrets files without a prompt; the read,
  # grep and glob tools cover file inspection and have their own rules.
  readOnlyBash = [
    "ls"
    "ls *"
    "pwd"
    "git status*"
    "git diff*"
    "git log*"
    "git show*"
    "git branch"
    "git branch --list*"
    "journalctl *"
    "systemctl status *"
    "systemctl is-active *"
    "systemctl is-enabled *"
    "systemctl list-units*"
    "systemctl list-timers*"
    "dmesg*"
    "lsblk*"
    "df"
    "df *"
    "free"
    "free *"
    "uname *"
    "ps"
    "ps *"
    "ss"
    "ss *"
    "ollama list"
    "ollama ps"
    "rocm-smi*"
    "nix eval *"
  ];

  trustedPatterns = map (dir: "${dir}/**") cfg.trustedDirs;

  # Private key material is never readable by the model; .env files keep
  # opencode's own default of asking. Shared by the global rules and the secrets
  # agent, because an agent-level `read` replaces the global one.
  readRules = {
    "*" = "allow";
    "*.env" = "ask";
    "*.env.*" = "ask";
    "*.env.example" = "allow";
  }
  // denyAll [
    "~/.gnupg/**"
    "~/.ssh/id_*"
  ];

  permission = {
    bash = {
      "*" = "ask";
    }
    // allowAll readOnlyBash;
    # File edits inside a trusted directory run without a prompt; every other
    # path asks. bash cannot be scoped to a directory (its patterns match the
    # command text, not the working directory), so a repo that should allow
    # every command gets its own opencode.json with "bash": "allow".
    edit = {
      "*" = "ask";
    }
    // allowAll trustedPatterns;
    read = readRules;
  }
  // lib.optionalAttrs (cfg.trustedDirs != [ ]) {
    external_directory = allowAll trustedPatterns;
  }
  // {
    # opencode also loads Claude-compatible skills from ~/.claude/skills and
    # .claude/skills. Those skills are written for Claude Code, so every agent
    # denies the skill tool; the secrets agent re-allows its one skill below.
    skill."*" = "deny";
  };

  # Bash rules for the secrets agent. Retrieval runs without a prompt; anything
  # that writes (gopass insert/generate/edit/mv/rm/sync, git push, op item
  # create/edit/delete, op run) matches only the "*" ask rule. gopass autosync
  # pushes each approved write to the secauto remote, which reader hosts pull
  # within 15 minutes. `op run` stays on ask because it executes whatever
  # command follows it with secrets injected.
  secretsBash = {
    "*" = "ask";
  }
  // allowAll [
    "gopass ls*"
    "gopass find*"
    "gopass search*"
    "gopass show*"
    "gopass cat*"
    "gopass git status*"
    "gopass git log*"
    "gopass git diff*"
    "gopass git pull*"
    "op whoami*"
    "op vault list*"
    "op item list*"
    "op item get*"
    "op read *"
    # opencode checks each stage of a pipeline on its own, and the model pipes
    # listings into a counter.
    "wc"
    "wc *"
  ]
  // denyAll [
    # Network and environment dumps: with retrieval on auto, these are the ways
    # a prompt-injected model could send a secret off the machine.
    "curl *"
    "wget *"
    "nc *"
    "ssh *"
    "scp *"
    "env"
    "env *"
    "printenv*"
    "op run --no-masking*"
  ];

  # Launcher for the secrets agent. opencode 2.x stores every session, including
  # any secret value the agent read, in a sqlite database under XDG_DATA_HOME,
  # and keeps prompt history under XDG_STATE_HOME. Pointing both at a per-run
  # directory in XDG_RUNTIME_DIR (tmpfs, 0700) means the transcript never
  # reaches disk and is removed when opencode exits, whether the agent cleaned
  # up or not. --standalone is required: without it the client talks to the
  # shared background service, which keeps its own data directory. Config stays
  # in the real XDG_CONFIG_HOME, so the provider and permission rules still
  # apply. The TUI has no --agent flag (only `run` does), so `opencode-secrets
  # run ...` forces the secrets agent and the interactive form needs Tab to
  # switch to it.
  opencode-secrets = pkgs.writeShellScriptBin "opencode-secrets" ''
    set -eu
    base="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}"
    data="$(${pkgs.coreutils}/bin/mktemp -d "$base/opencode-secrets.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -rf "$data"' EXIT
    export XDG_DATA_HOME="$data" XDG_STATE_HOME="$data/state"
    if [ "''${1:-}" = run ]; then
      shift
      ${pkgs.opencode}/bin/opencode run --standalone --agent secrets "$@"
    else
      ${pkgs.opencode}/bin/opencode --standalone "$@"
    fi
  '';

  # Binaries are pinned by store path in the commands above, but keep the
  # servers on PATH too (the Zed/Helix belt-and-suspenders pattern). golangci-lint
  # is included because golangci-lint-langserver shells out to it by name.
  lspPackages = with pkgs; [
    nixd
    gopls
    golangci-lint-langserver
    golangci-lint
    rust-analyzer
    terraform-ls
    taplo
    yaml-language-server
    yaml-schema-router
    bash-language-server
    marksman
    harper
    kotlin-lsp
  ];
in
{
  options = {
    apps.cli.opencode.enable = lib.mkEnableOption "the opencode CLI agent with LSP language servers";

    apps.cli.opencode.trustedDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "~/git" ];
      description = ''
        Directories where opencode edits files without asking. Each entry
        becomes an `edit` and `external_directory` allow rule for `<dir>/**`;
        edits anywhere else ask. Leading `~` is expanded by opencode. This
        scopes file edits only: bash rules match command text, so allowing every
        command in a repo takes an opencode.json in that repo.
      '';
    };

    apps.cli.opencode.secretsAgent = {
      enable = lib.mkEnableOption "the secrets agent and the opencode-secrets launcher (qbert only)";

      model = lib.mkOption {
        type = lib.types.str;
        example = "ollama/qwen3.6:35b-a3b";
        description = ''
          Local model for the secrets agent, as `<provider>/<model>`. It must be
          a model served from this host: the agent reads secret values with no
          approval prompt, and the session text stays on the machine only if the
          model does too.
        '';
      };
    };

    apps.cli.opencode.remoteOllama = {
      enable = lib.mkEnableOption "a remote Ollama server (qbert over Tailscale) as the default opencode provider";

      host = lib.mkOption {
        type = lib.types.str;
        example = "100.74.137.95";
        description = "Tailscale address of the host running apps.cli.ollama with serveOnTailscale.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 11434;
        description = "Port the remote Ollama listens on.";
      };

      model = lib.mkOption {
        type = lib.types.str;
        example = "qwen3.6:35b-a3b";
        description = "Model the remote server has pulled; becomes the opencode default.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      # enable installs the package and lets other modules (e.g. ollama's local
      # provider/model wiring) contribute to ~/.config/opencode/opencode.json via
      # programs.opencode.settings, which is merged with the lsp block below.
      programs.opencode = {
        enable = true;
        # nixpkgs, not llm-agents: llm-agents.nix packages GitHub release
        # assets and upstream stopped publishing releases at 1.19.3, while
        # nixpkgs builds the 2.x tags from source (2.0.32 at the locked rev).
        package = pkgs.opencode;
        settings = {
          lsp = lspServers;
          inherit permission;
        }
        // lib.optionalAttrs cfg.secretsAgent.enable {
          # Primary agent, reached with Tab or `opencode-secrets run ...`. "*"
          # denies every tool not listed, which drops webfetch, websearch, task
          # (other models), skill and MCP tools. Merged with the global rules
          # above, with the agent's rules winning.
          agent.secrets = {
            description = "gopass and 1Password management on the local model";
            mode = "primary";
            inherit (cfg.secretsAgent) model;
            permission = {
              "*" = "deny";
              bash = secretsBash;
              read = readRules;
              glob = "allow";
              grep = "allow";
              todowrite = "allow";
              question = "allow";
              skill = {
                "*" = "deny";
                secrets = "allow";
              };
            };
          };
        }
        // lib.optionalAttrs cfg.remoteOllama.enable {
          model = "ollama-remote/${cfg.remoteOllama.model}";
          provider.ollama-remote = {
            npm = "@ai-sdk/openai-compatible";
            name = "Ollama (remote, Tailscale)";
            options.baseURL = "http://${cfg.remoteOllama.host}:${toString cfg.remoteOllama.port}/v1";
            models.${cfg.remoteOllama.model} = { };
          };
        };
      };

      home.packages = lspPackages ++ lib.optional cfg.secretsAgent.enable opencode-secrets;

      # The secrets skill lives here and not in claude-skills or ~/.claude/skills:
      # Claude Code loads both, and a secrets workflow written for a local model
      # must not reach it. opencode reads this path natively.
      xdg.configFile."opencode/skills/secrets/SKILL.md" = lib.mkIf cfg.secretsAgent.enable {
        source = ./cfg/skills/secrets/SKILL.md;
      };
    };
  };
}
