{
  globals,
  inputs,
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

  # Import configuration fragments (symlink-based, stay as home.file)
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
  gsdConfig = import ./cfg/gsd.nix {
    inherit pkgs versions;
  };
  fishConfig = import ./cfg/fish.nix {
    inherit globals statusLineScript;
  };

  # Status line script -- jq, curl, gawk in PATH via runtimeInputs
  statusLineScript = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [
      pkgs.jq
      pkgs.curl
      pkgs.gawk
    ];
    text = builtins.readFile ./statusline.sh;
  };

  # Shell scripts -- read from files, substitute placeholders
  k8s-mcp-setup = builtins.replaceStrings [ "@KUBECONFIG_FILE@" ] [ kubeconfigFile ] (
    builtins.readFile ./cfg/scripts/k8s-mcp-setup.fish
  );

  mcpPick = builtins.readFile ./cfg/scripts/mcp-pick.bash;

  # Path to config directory (Nix store copy for activation script)
  configDir = ./config;
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
          llm-agents.claude-code
          libnotify # for notify-send in Stop hook
        ]
        ++ gsdConfig.packages;

      programs.fish = fishConfig;

      # Copy config files as writable copies via activation script.
      # This replaces programs.claude-code.{settings,memory,agents,skills,outputStyles}
      # so that Claude Code can modify its own config at runtime.
      home.activation.claudeCodeConfig = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        claude_home="${homeDir}/.claude"

        # Create directories
        $DRY_RUN_CMD mkdir -p "$claude_home/agents"
        $DRY_RUN_CMD mkdir -p "$claude_home/skills"
        $DRY_RUN_CMD mkdir -p "$claude_home/output-styles"

        # settings.json -- substitute statusline store path
        if [ -z "$DRY_RUN_CMD" ]; then
          ${pkgs.gnused}/bin/sed \
            's|@STATUSLINE_COMMAND@|${statusLineScript}/bin/claude-statusline|g' \
            "${configDir}/settings.json" > "$claude_home/settings.json"
          chmod 644 "$claude_home/settings.json"
        else
          $DRY_RUN_CMD "would substitute @STATUSLINE_COMMAND@ in settings.json"
        fi

        # CLAUDE.md
        $DRY_RUN_CMD cp --no-preserve=mode "${configDir}/CLAUDE.md" "$claude_home/CLAUDE.md"

        # Agents
        for agent in "${configDir}"/agents/*.md; do
          $DRY_RUN_CMD cp --no-preserve=mode "$agent" "$claude_home/agents/$(basename "$agent")"
        done

        # Skills (copy directories recursively, only Nix-managed ones)
        for skill_dir in "${configDir}"/skills/*/; do
          skill_name="$(basename "$skill_dir")"
          $DRY_RUN_CMD mkdir -p "$claude_home/skills/$skill_name"
          $DRY_RUN_CMD cp --no-preserve=mode -r "$skill_dir"* "$claude_home/skills/$skill_name/"
        done

        # Output styles
        for style in "${configDir}"/output-styles/*; do
          $DRY_RUN_CMD cp --no-preserve=mode "$style" "$claude_home/output-styles/$(basename "$style")"
        done
      '';

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
