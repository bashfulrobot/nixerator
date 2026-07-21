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
  fluxOperatorMcp = pkgs.callPackage ./build/flux-operator-mcp.nix { inherit versions; };
  isoTopologyPkg = pkgs.callPackage ../iso-topology/build { inherit versions; };
  homeDir = globals.user.homeDirectory;
  kubeconfigFile = "${homeDir}/.kube/mcp-viewer.kubeconfig";

  # Import configuration fragments (symlink-based, stay as home.file)
  mcpConfig = import ./cfg/mcp-servers.nix {
    inherit
      lib
      pkgs
      secrets
      kubernetesMcpServer
      fluxOperatorMcp
      isoTopologyPkg
      kubeconfigFile
      homeDir
      ;
    inherit (cfg) serverProfile;
  };
  contextsConfig = import ./cfg/contexts.nix {
    inherit lib;
    inherit (mcpConfig) mcpServers;
  };
  lspConfig = import ./cfg/lsp-plugins.nix { inherit lib; };
  # Declarative, SHA-pinned plugin surface. mkOverlay turns the per-host
  # cfg.plugins list into the { extraKnownMarketplaces, enabledPlugins } object
  # merged into settings.json at activation (and stripped from capture so Nix
  # owns these keys). Replaces the old imperative cfg/plugins.nix sync.
  pluginConfig = import ./cfg/plugin-config.nix { inherit lib; };
  pluginOverlayFile = pkgs.writeText "claude-plugin-overlay.json" (
    builtins.toJSON (pluginConfig.mkOverlay cfg.plugins)
  );
  skillUpdatesConfig = import ./cfg/skill-updates.nix {
    inherit pkgs;
  };
  reapConfig = import ./cfg/reap.nix {
    inherit pkgs versions;
    homeDir = globals.user.homeDirectory;
  };
  fishConfig = import ./cfg/fish.nix {
    inherit globals pkgs statusLineScript;
  };
  activationConfig = import ./cfg/activation.nix {
    inherit
      pkgs
      configDir
      statusLineScript
      autoGateScript
      precompactScript
      reinjectScript
      remindersFile
      remindersScript
      guardGeneratedPathsScript
      guardRawNixScript
      guardGitStashScript
      reapConfig
      globals
      homeDir
      ;
    humanizerSkillSrc = inputs.humanizer-skill;
    # Reference the rules file by path, not through
    # `config.apps.cli.text-polish.rulesFile`. Reading the option made this
    # module fail to evaluate on any host that imports claude-code without
    # text-polish (srv, #246). The option is readOnly with this exact path as
    # its default, so the two can't drift, and activation only ever `cp`s it.
    textPolishRulesFile = ../text-polish/prompt/concision-rules.md;
    pluginOverlay = pluginOverlayFile;
    userScopeMcpTemplate = userScopeMcpTemplateFile;
    inherit secretsFile;
  };

  # Secret-free user-scope MCP template (see cfg/mcp-servers.nix). Safe to land
  # in the Nix store: the PAT is a @KONG_KONNECT_PAT@ placeholder that
  # activation fills from secretsFile at runtime.
  userScopeMcpTemplateFile = pkgs.writeText "claude-mcp-user-scope.json" mcpConfig.userScopeTemplate;
  secretsFile = "${homeDir}/.config/nixos-secrets/secrets.json";

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

  # PreToolUse permission gate for /auto autonomous sessions. Sole arbiter for
  # rm/kill/pkill, gated by the session-bound ~/.claude/.auto-mode-active
  # sentinel (see config/skills/auto/references/permission-model.md). jq + grep
  # on PATH via runtimeInputs.
  autoGateScript = pkgs.writeShellApplication {
    name = "claude-auto-gate";
    runtimeInputs = [
      pkgs.jq
      pkgs.gnugrep
      pkgs.coreutils
    ];
    text = builtins.readFile ./cfg/scripts/auto-gate.sh;
  };

  # Context-rot survival. PreCompact writes a recovery snapshot + a per-session
  # sentinel; the next UserPromptSubmit re-injects the hard rules once and clears
  # it. Both are injected at activation and stripped on capture (cfg/fish.nix),
  # so their volatile store paths are never committed (the dead tmux-claude bug).
  precompactScript = pkgs.writeShellApplication {
    name = "claude-precompact-checkpoint";
    runtimeInputs = [
      pkgs.jq
      pkgs.git
      pkgs.coreutils
      pkgs.findutils
    ];
    text = builtins.readFile ./cfg/scripts/precompact-checkpoint.sh;
  };
  reinjectScript = pkgs.writeShellApplication {
    name = "claude-post-compact-reinject";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = builtins.readFile ./cfg/scripts/post-compact-reinject.sh;
  };

  # SessionStart date-gated maintenance reminders, read from the Nix-rendered
  # registry deployed to ~/.claude/reminders.json (cfg/reminders.nix).
  remindersFile = import ./cfg/reminders.nix { inherit pkgs; };
  remindersScript = pkgs.writeShellApplication {
    name = "claude-session-reminders";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = builtins.readFile ./cfg/scripts/reminders.sh;
  };

  # Hardened PostToolUse guards (warn-level): editing Nix-generated ~/.claude
  # files, and raw `nix` commands outside justfile recipes.
  guardGeneratedPathsScript = pkgs.writeShellApplication {
    name = "claude-guard-generated-paths";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = builtins.readFile ./cfg/scripts/guard-generated-paths.sh;
  };
  guardRawNixScript = pkgs.writeShellApplication {
    name = "claude-guard-raw-nix";
    runtimeInputs = [
      pkgs.jq
      pkgs.gnugrep
      pkgs.coreutils
    ];
    text = builtins.readFile ./cfg/scripts/guard-raw-nix.sh;
  };

  # Hard PreToolUse deny for manual `git stash` (issue #250). Unlike the
  # warn-level guards above, this blocks the command before it runs, because a
  # stash pushed onto the shared refs/stash stack is already a hazard the
  # moment a second agent is active in the repo. PreToolUse deny composes with
  # the auto-gate (an allow can never override a deny).
  guardGitStashScript = pkgs.writeShellApplication {
    name = "claude-guard-git-stash";
    runtimeInputs = [
      pkgs.jq
      pkgs.gnugrep
      pkgs.coreutils
    ];
    text = builtins.readFile ./cfg/scripts/guard-git-stash.sh;
  };

  # Shell scripts -- read from files, substitute placeholders
  k8s-mcp-setup = builtins.replaceStrings [ "@KUBECONFIG_FILE@" ] [ kubeconfigFile ] (
    builtins.readFile ./cfg/scripts/k8s-mcp-setup.fish
  );

  mcpPick = builtins.readFile ./cfg/scripts/mcp-pick.bash;

  # Path to config directory (Nix store copy for activation script)
  configDir = ./config;

  # Hyperframes plugin needs ffmpeg, node, puppeteer env vars, and a
  # Chromium-family browser binary on the host. Gate the runtime deps on
  # plugin-list membership so the closure is unchanged on hosts where the
  # plugin isn't enabled.
  #
  # The browser itself is NOT provisioned from this gate -- it's whatever the
  # user has nominated via `globals.preferences.browser` and installed via the
  # appropriate browser module (today: `apps.gui.google-chrome` via
  # `suites.browsers`, binary at /run/current-system/sw/bin/google-chrome-stable).
  # PUPPETEER_EXECUTABLE_PATH resolves the preferred-browser binary name through
  # /run/current-system/sw/bin so a future switch to chromium / brave / vivaldi
  # is one globals.preferences.browser flip away. This intentionally couples to
  # the user's XDG-style preference slot rather than hardcoding a package.
  hasHyperframes = lib.elem "hyperframes@hyperframes" cfg.plugins;
  hyperframesBrowserPath = "/run/current-system/sw/bin/${globals.preferences.browser}";

  # Conditional env vars exported into both system and HM session scopes.
  # Built once here so the two consumer sites can't drift.
  claudeEnv =
    lib.optionalAttrs (secrets ? gemini && secrets.gemini ? apiKey) {
      GEMINI_API_KEY = secrets.gemini.apiKey;
    }
    // lib.optionalAttrs (secrets ? aha && secrets.aha ? apiToken) {
      # Aha! REST API token for the `aha` Claude Code skill. Injected as an
      # env var the same way as GEMINI_API_KEY so `aha.sh` reads it directly
      # (no runtime `op` call, no Personal-vault dependency). Sourced from the
      # `nixerator` vault via secrets.json.tpl.
      AHA_API_TOKEN = secrets.aha.apiToken;
    }
    // lib.optionalAttrs (secrets ? wave && secrets.wave ? fullAccessToken) {
      # Wave Full Access Token for the `wave-invoicing` skill. Injected as an
      # env var the same way as AHA_API_TOKEN so the skill reads it directly
      # (no runtime `op` call). Sourced from the `nixerator` vault via
      # secrets.json.tpl. Full Access Token = personal-use bearer token; no
      # OAuth client/secret/refresh flow.
      WAVE_FULL_ACCESS_TOKEN = secrets.wave.fullAccessToken;
    }
    // lib.optionalAttrs hasHyperframes {
      PUPPETEER_EXECUTABLE_PATH = hyperframesBrowserPath;
      PUPPETEER_SKIP_DOWNLOAD = "1";
    }
    // {
      # Force conversation auto-compaction at 400k tokens — below the point
      # where 1M-context Opus quality measurably degrades. Env var name
      # verified by string-grepping the claude-code binary; not yet in
      # public docs as of 2026-05-27.
      CLAUDE_CODE_AUTO_COMPACT_WINDOW = "400000";
    };
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
        description = ''
          Plugin identifiers ("<plugin>@<marketplace>") to enable for this host.
          Definitions from multiple modules merge. Drives the declarative,
          SHA-pinned settings.json overlay (cfg/plugin-config.nix): each id is
          enabled and its (non-built-in) marketplace is registered + pinned.
        '';
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
        # for rendering and a Chromium-family browser via puppeteer for HTML
        # capture. The browser binary itself is whatever the user nominates
        # via `globals.preferences.browser` (provisioned by suites.browsers
        # or equivalent) -- not added here. Puppeteer is pointed at it via
        # PUPPETEER_EXECUTABLE_PATH below.
        pkgs.ffmpeg-full
      ];

    # Gemini API key for generate-images / visual-explainer skills.
    # Puppeteer env vars only applied when the hyperframes plugin is enabled --
    # keeps the system environment clean on hosts that don't use it.
    # `claudeEnv` (see `let` block) builds this attrset once; reused below
    # for `home.sessionVariables` so the two scopes can't drift.
    environment.variables = claudeEnv;

    home-manager.users.${globals.user.name} = {
      programs.fish = fishConfig;

      home = {
        sessionVariables = claudeEnv;
        packages =
          (with pkgs; [
            llm-agents.claude-code
          ])
          ++ lib.optionals (cfg.serverProfile == "full") (
            with pkgs;
            [
              libnotify # for notify-send in Stop hook (workstation-only)
              sox # rec on PATH -- required for Claude Code /voice audio recording (workstation-only)
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
          ++ skillUpdatesConfig.packages
          ++ reapConfig.packages;

        # Copy config files as writable copies via activation script.
        # This replaces programs.claude-code.{settings,memory,agents,skills,outputStyles}
        # so that Claude Code can modify its own config at runtime.
        activation.claudeCodeConfig = inputs.home-manager.lib.hm.dag.entryAfter [
          "writeBoundary"
        ] activationConfig.text;

        # Preserve per-server files for mcp-pick workflow compatibility.
        file = mcpConfig.files // lspConfig.files // contextsConfig.files;
      };
    };
  };
}
