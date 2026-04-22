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
  contextsConfig = import ./cfg/contexts.nix {
    inherit lib;
    inherit (mcpConfig) mcpServers;
  };
  lspConfig = import ./cfg/lsp-plugins.nix { inherit lib; };
  pluginsConfig = import ./cfg/plugins.nix {
    inherit pkgs;
    desiredPlugins = cfg.plugins;
  };
  reapConfig = import ./cfg/reap.nix {
    inherit pkgs versions;
    homeDir = globals.user.homeDirectory;
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
      plugins = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Plugin identifiers to install (e.g., 'ralph-loop@claude-plugins-official').";
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

    # Gemini API key for generate-images / visual-explainer skills
    environment.variables = lib.optionalAttrs (secrets ? gemini && secrets.gemini ? apiKey) {
      GEMINI_API_KEY = secrets.gemini.apiKey;
    };

    home-manager.users.${globals.user.name} = {
      programs.fish = fishConfig;

      home = {
        sessionVariables = lib.optionalAttrs (secrets ? gemini && secrets.gemini ? apiKey) {
          GEMINI_API_KEY = secrets.gemini.apiKey;
        };
        packages =
          with pkgs;
          [
            llm-agents.claude-code
            libnotify # for notify-send in Stop hook
          ]
          ++ pluginsConfig.packages
          ++ reapConfig.packages;

        # Copy config files as writable copies via activation script.
        # This replaces programs.claude-code.{settings,memory,agents,skills,outputStyles}
        # so that Claude Code can modify its own config at runtime.
        activation.claudeCodeConfig = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          claude_home="${homeDir}/.claude"

          # Create directories
          $DRY_RUN_CMD mkdir -p "$claude_home/agents"
          $DRY_RUN_CMD mkdir -p "$claude_home/skills"
          $DRY_RUN_CMD mkdir -p "$claude_home/output-styles"

          # CLAUDE.md -- global instructions
          $DRY_RUN_CMD rm -f "$claude_home/CLAUDE.md"
          $DRY_RUN_CMD cp --no-preserve=mode "${configDir}/CLAUDE.md" "$claude_home/CLAUDE.md"

          # settings.json -- substitute statusline store path
          # Remove first in case it's a stale symlink into the nix store (read-only)
          if [ -z "$DRY_RUN_CMD" ]; then
            rm -f "$claude_home/settings.json"
            ${pkgs.gnused}/bin/sed \
              -e 's|@STATUSLINE_COMMAND@|${statusLineScript}/bin/claude-statusline|g' \
              -e 's|@USER_NAME@|${globals.user.name}|g' \
              -e 's|@HOME_DIR@|${globals.user.homeDirectory}|g' \
              "${configDir}/settings.json" > "$claude_home/settings.json"
            chmod 644 "$claude_home/settings.json"
          else
            $DRY_RUN_CMD "would substitute @STATUSLINE_COMMAND@ in settings.json"
          fi

          # Agents -- remove stale symlinks before copying
          for agent in "${configDir}"/agents/*.md; do
            $DRY_RUN_CMD rm -f "$claude_home/agents/$(basename "$agent")"
            $DRY_RUN_CMD cp --no-preserve=mode "$agent" "$claude_home/agents/$(basename "$agent")"
          done

          # Skills (copy directories recursively, only Nix-managed ones)
          for skill_dir in "${configDir}"/skills/*/; do
            skill_name="$(basename "$skill_dir")"
            # Clean and recreate to handle subdirectories (e.g. references/)
            $DRY_RUN_CMD rm -rf "$claude_home/skills/$skill_name"
            $DRY_RUN_CMD mkdir -p "$claude_home/skills/$skill_name"
            $DRY_RUN_CMD cp --no-preserve=mode -r "$skill_dir"* "$claude_home/skills/$skill_name/"
          done

          # Output styles -- remove stale symlinks before copying
          for style in "${configDir}"/output-styles/*; do
            $DRY_RUN_CMD rm -f "$claude_home/output-styles/$(basename "$style")"
            $DRY_RUN_CMD cp --no-preserve=mode "$style" "$claude_home/output-styles/$(basename "$style")"
          done

          # OpenTabs MCP -- bridge runtime secret into mcp-pick directory
          opentabs_auth="${homeDir}/.opentabs/extension/auth.json"
          opentabs_mcp_dir="$claude_home/mcp-servers/opentabs"
          if [ -f "$opentabs_auth" ]; then
            $DRY_RUN_CMD mkdir -p "$opentabs_mcp_dir"
            if [ -z "$DRY_RUN_CMD" ]; then
              secret="$(${pkgs.jq}/bin/jq -r '.secret' "$opentabs_auth")"
              printf '{"mcpServers":{"opentabs":{"type":"http","url":"http://127.0.0.1:9515/mcp","headers":{"Authorization":"Bearer %s"}}}}\n' "$secret" > "$opentabs_mcp_dir/.mcp.json"
              chmod 600 "$opentabs_mcp_dir/.mcp.json"
            fi
          fi

          # REAP -- deploy slash commands to ~/.reap/commands/
          ${reapConfig.activation}

          # Plugins -- deploy captured plugin config and cache
          plugins_src="${configDir}/plugins"
          if [ -d "$plugins_src" ]; then
            $DRY_RUN_CMD mkdir -p "$claude_home/plugins"

            # installed_plugins.json -- substitute @HOME_DIR@ placeholder
            if [ -f "$plugins_src/installed_plugins.json" ]; then
              if [ -z "$DRY_RUN_CMD" ]; then
                rm -f "$claude_home/plugins/installed_plugins.json"
                ${pkgs.gnused}/bin/sed 's|@HOME_DIR@|${homeDir}|g' \
                  "$plugins_src/installed_plugins.json" > "$claude_home/plugins/installed_plugins.json"
                chmod 644 "$claude_home/plugins/installed_plugins.json"
              fi
            fi

            # known_marketplaces.json -- substitute @HOME_DIR@ placeholder
            if [ -f "$plugins_src/known_marketplaces.json" ]; then
              if [ -z "$DRY_RUN_CMD" ]; then
                rm -f "$claude_home/plugins/known_marketplaces.json"
                ${pkgs.gnused}/bin/sed 's|@HOME_DIR@|${homeDir}|g' \
                  "$plugins_src/known_marketplaces.json" > "$claude_home/plugins/known_marketplaces.json"
                chmod 644 "$claude_home/plugins/known_marketplaces.json"
              fi
            fi

            # blocklist.json -- plain copy
            if [ -f "$plugins_src/blocklist.json" ]; then
              $DRY_RUN_CMD rm -f "$claude_home/plugins/blocklist.json"
              $DRY_RUN_CMD cp --no-preserve=mode "$plugins_src/blocklist.json" "$claude_home/plugins/blocklist.json"
            fi

            # Plugin cache not tracked in git -- Claude Code auto-downloads from installed_plugins.json
          fi
        '';

        # Preserve per-server files for mcp-pick workflow compatibility.
        file = mcpConfig.files // lspConfig.files // contextsConfig.files;
      };
    };
  };
}
