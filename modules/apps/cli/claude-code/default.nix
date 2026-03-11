{
  globals,
  lib,
  pkgs,
  config,
  secrets,
  versions,
  ...
}:

let
  cfg = config.apps.cli.claude-code;
  kubernetesMcpServer = pkgs.callPackage ./build { inherit versions; };
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
  globalHooks = import ./cfg/hooks-global.nix { inherit lib; };
  nixeratorHooks = import ./cfg/hooks-nixerator.nix { inherit lib; };
  gsdConfig = import ./cfg/gsd.nix {
    inherit pkgs versions;
    homeDir = globals.user.homeDirectory;
  };
  hooks = {
    SessionStart = globalHooks.SessionStart ++ (gsdConfig.hooks.SessionStart or [ ]);
    PostToolUse =
      globalHooks.PostToolUse ++ nixeratorHooks.PostToolUse ++ (gsdConfig.hooks.PostToolUse or [ ]);
    Stop = globalHooks.Stop;
  };
  fishConfig = import ./cfg/fish.nix;

  # Status line script — jq, curl, gawk in PATH via runtimeInputs
  statusLineScript = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [
      pkgs.jq
      pkgs.curl
      pkgs.gawk
    ];
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
      home.packages =
        with pkgs;
        [
          libnotify # for notify-send in Stop hook
        ]
        ++ gsdConfig.packages;

      programs = {
        claude-code = {
          enable = true;
          package = pkgs.llm-agents.claude-code;

          # Settings (JSON config)
          settings = {
            cleanupPeriodDays = 15;
            coAuthor = "";
            remoteControlEnabled = true;

            # Status line — three-line display with model/tokens, usage bars, and reset times
            statusLine = {
              type = "command";
              command = "${statusLineScript}/bin/claude-statusline";
            };

            # Permissions - auto-approve common Nix and git operations
            permissions.allow = permissions;

            inherit hooks;
          };

          # Memory file (CLAUDE.md - project rules and context)
          memory.text = builtins.readFile ../../../../CLAUDE.md + ''

            ## Writing Style

            - Never use em dashes (—) in output. Use commas, periods, semicolons, parentheses, or rewrite the sentence instead.

            ## Docs (open only when needed)

            - `~/.claude/docs/tools.md` -- custom CLI tools; check when a task might benefit from an installed tool.

            ## Autonomy

            - In plan mode, use Explore subagents proactively for research. Do not ask for permission to research; just launch agents.
            - Prefer domain-specialized agents (nix, go, rust, frontend, etc.) over generic exploration when the task clearly falls in one domain.
            - Use all available research tools freely: Glob, Grep, Read, WebSearch, WebFetch, find, fd, rg, cat, bat, amber, and Bash for exploration. These are pre-approved.
            - MCP servers are per-project (via mcp-pick). Only reference MCP tools if they appear in the current project's .mcp.json.
            - Before entering plan mode for any task, ask the user: "Would you like to use GSD for this?" Simple yes/no, asked once at the start of every planning session.
          '';

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

          skills = {
            commit = ./skills/commit;
            humanizer = ./skills/humanizer;
            branch-status = ./skills/branch-status;
            github-issue = ./skills/github-issue;
            csat = ./skills/csat;
          };

          outputStyles.compact = ./output-styles/compact.md;
        };

        fish = fishConfig;
      };

      # Preserve per-server files for mcp-pick workflow compatibility.
      # Place global docs in ~/.claude/docs/ for lazy-loaded context.
      home.file =
        mcpConfig.files
        // lspConfig.files
        // {
          ".claude/docs/tools.md".source = ../../../../extras/docs/tools.md;
        };
    };
  };
}
