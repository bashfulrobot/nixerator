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

      home.packages = lspPackages;
    };
  };
}
