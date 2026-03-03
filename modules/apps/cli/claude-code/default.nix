{
  globals,
  lib,
  pkgs,
  config,
  secrets,
  ...
}:

let
  cfg = config.apps.cli.claude-code;
  kubernetesMcpServer = pkgs.callPackage ./build { };
  homeDir = globals.user.homeDirectory;
  kubeconfigFile = "${homeDir}/.kube/mcp-viewer.kubeconfig";

  # Import configuration fragments
  mcpConfig = import ./cfg/mcp-servers.nix {
    inherit
      lib
      pkgs
      secrets
      kubernetesMcpServer
      kubeconfigFile
      ;
  };
  lspConfig = import ./cfg/lsp-plugins.nix { inherit lib; };
  permissions = import ./cfg/permissions.nix;
  hooks = import ./cfg/hooks.nix { inherit lib; };
  fishConfig = import ./cfg/fish.nix;

  # Status line script — jq is in PATH via runtimeInputs
  statusLineScript = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./statusline.sh;
  };

  # Shell scripts — read from files, substitute placeholders
  k8s-mcp-setup = builtins.replaceStrings [ "@KUBECONFIG_FILE@" ] [ kubeconfigFile ] (
    builtins.readFile ./cfg/scripts/k8s-mcp-setup.fish
  );

  mcpPick = builtins.readFile ./cfg/scripts/mcp-pick.bash;
in
{
  options = {
    apps.cli.claude-code = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable claude-code CLI tool with custom configuration.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # System packages for MCP tooling and LSP servers
    environment.systemPackages = with pkgs; [
      (writeScriptBin "k8s-mcp-setup" k8s-mcp-setup)
      (writeScriptBin "mcp-pick" mcpPick)
      llm-agents.claude-plugins # Plugin & skills manager
      fzf
      jq

      # Language servers for Claude Code LSP integration
      bash-language-server
      dart
      gopls
      lua-language-server
      pyright
      rust-analyzer
      terraform-ls
      vtsls
      yaml-language-server
    ];

    home-manager.users.${globals.user.name} = {
      home.packages = with pkgs; [
        libnotify # for notify-send in Stop hook
      ];

      programs = {
        claude-code = {
          enable = true;
          package = pkgs.llm-agents.claude-code;

          # Settings (JSON config)
          settings = {
            cleanupPeriodDays = 15;
            coAuthor = "";
            remoteControlEnabled = true;

            # Status line — two-line display with model, git, tokens, cost, duration
            statusLine = {
              type = "command";
              command = "${statusLineScript}/bin/claude-statusline";
            };

            # Permissions - auto-approve common Nix and git operations
            permissions.allow = permissions;

            inherit hooks;
          };

          # Memory file (CLAUDE.md - project rules and context)
          memory.text = builtins.readFile ../../../../CLAUDE.md;

          # Agents (subagents for specialized tasks)
          agents = {
            rust = builtins.readFile ./agents/rust.md;
            frontend = builtins.readFile ./agents/frontend.md;
            testing = builtins.readFile ./agents/testing.md;
            product = builtins.readFile ./agents/product.md;
            go = builtins.readFile ./agents/go.md;
            api = builtins.readFile ./agents/api.md;
            nix = builtins.readFile ./agents/nix.md;
            bash = builtins.readFile ./agents/bash.md;
            devops = builtins.readFile ./agents/devops.md;
            eleventy = builtins.readFile ./agents/eleventy.md;
          };

          # No global MCP servers — use mcp-pick per-project to avoid
          # bloating every conversation with unused tool schemas.
          mcpServers = { };

          skills.commit = ./skills/commit;
          skills.humanizer = ./skills/humanizer;

          outputStyles.compact = ./output-styles/compact.md;
        };

        fish = fishConfig;
      };

      # Preserve per-server files for mcp-pick workflow compatibility.
      home.file = mcpConfig.files // lspConfig.files;
    };
  };
}
