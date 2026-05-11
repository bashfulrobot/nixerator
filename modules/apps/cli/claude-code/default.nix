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
    inherit (cfg) serverProfile;
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
    inherit globals pkgs statusLineScript;
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

  # Hyperframes plugin requires ffmpeg + chromium + node + puppeteer env vars
  # on the host. Gate the runtime deps on plugin-list membership so the
  # closure is unchanged on hosts where the plugin isn't enabled.
  hasHyperframes = lib.elem "hyperframes@hyperframes" cfg.plugins;
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
      serverProfile = lib.mkOption {
        type = lib.types.enum [
          "full"
          "minimal"
        ];
        default = "full";
        description = ''
          Selects which MCP servers and host-specific entries are emitted into
          the generated Claude Code config.

          * "full"    -- Workstation profile. Includes kubernetes-mcp-server
                         (requires a host-local kubeconfig).
          * "minimal" -- Headless / server profile. Drops kubernetes-mcp-server
                         and any other entries that require host-local files.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # System packages for MCP tooling and LSP servers
    environment.systemPackages =
      (with pkgs; [
        (writeScriptBin "mcp-pick" mcpPick)
        llm-agents.claude-plugins # Plugin & skills manager
        fzf
        jq
        rsync # used by claude-capture + activation to mirror skills

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
      ])
      ++ lib.optionals (cfg.serverProfile == "full") [
        # k8s-mcp-setup is the operator script that wires kubernetes-mcp-server
        # against a host-local kubeconfig. Pointless on minimal-profile hosts
        # where the kubernetes MCP server itself is gated out.
        (pkgs.writeScriptBin "k8s-mcp-setup" k8s-mcp-setup)
      ]
      ++ lib.optionals hasHyperframes [
        # Hyperframes plugin invokes `npx hyperframes` which spawns ffmpeg
        # for rendering and a system chromium via puppeteer for HTML capture.
        # Puppeteer's bundled chromium binary does not run on NixOS, so the
        # system chromium becomes the puppeteer target via env vars below.
        pkgs.ffmpeg-full
        pkgs.chromium
      ];

    # Gemini API key for generate-images / visual-explainer skills.
    # Puppeteer env vars only applied when the hyperframes plugin is enabled --
    # keeps the system environment clean on hosts that don't use it.
    environment.variables =
      lib.optionalAttrs (secrets ? gemini && secrets.gemini ? apiKey) {
        GEMINI_API_KEY = secrets.gemini.apiKey;
      }
      // lib.optionalAttrs hasHyperframes {
        PUPPETEER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
        PUPPETEER_SKIP_DOWNLOAD = "1";
      };

    home-manager.users.${globals.user.name} = {
      programs.fish = fishConfig;

      home = {
        sessionVariables =
          lib.optionalAttrs (secrets ? gemini && secrets.gemini ? apiKey) {
            GEMINI_API_KEY = secrets.gemini.apiKey;
          }
          // lib.optionalAttrs hasHyperframes {
            PUPPETEER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
            PUPPETEER_SKIP_DOWNLOAD = "1";
          };
        packages =
          (with pkgs; [
            llm-agents.claude-code
          ])
          ++ lib.optionals (cfg.serverProfile == "full") (
            with pkgs;
            [
              libnotify # for notify-send in Stop hook (workstation-only)
              libreoffice # soffice on PATH -- required for marp-slides skill's --pptx-editable export (workstation-only)
            ]
          )
          ++ lib.optionals hasHyperframes [
            # Hyperframes upstream requires Node >= 22. The `apps.cli.pnpm`
            # module (via suites.dev) also installs `pkgs.nodejs` -- both
            # nodejs derivations ship `lib/node_modules/corepack/dist/yarnpkg.js`,
            # so plain `pkgs.nodejs_22` collides. `lib.hiPrio` lifts nodejs_22
            # above the default nodejs in buildEnv's collision resolution and
            # keeps the hyperframes branch self-contained -- the gate no longer
            # silently depends on suites.dev being co-enabled.
            (lib.hiPrio pkgs.nodejs_22)
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

          # Skills -- mirror each Nix-managed skill into ~/.claude/skills/<skill>/
          # using rsync. --delete prunes anything removed from source.
          # --chmod=u+w makes files writable so Claude Code can edit them at runtime
          # (Nix store content is read-only otherwise).
          for skill_dir in "${configDir}"/skills/*/; do
            skill_name="$(basename "$skill_dir")"
            $DRY_RUN_CMD mkdir -p "$claude_home/skills/$skill_name"
            $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -a --delete --chmod=u+w \
              "$skill_dir" "$claude_home/skills/$skill_name/"
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
