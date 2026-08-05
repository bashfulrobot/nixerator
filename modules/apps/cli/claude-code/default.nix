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
  # Default-off skill surface (see cfg/skill-defaults.nix for the always-on
  # baseline and why each entry earned its spot). Same overlay pattern as
  # pluginOverlayFile above: force-merged into settings.json at activation,
  # stripped from capture, so Nix owns the default and a per-project
  # skill-pick "on" is the only way around it.
  skillDefaultsConfig = import ./cfg/skill-defaults.nix { inherit lib; };
  # The seven VibeCurb design skills all live under skills/<name>/SKILL.md
  # in the same upstream repo (see cfg/activation.nix for the symlink loop
  # that consumes this same list).
  vibecurbSkillNames = [
    "awwwards-hero"
    "awwwards-motion"
    "awwwards-sections"
    "brandkit-gen"
    "imagegen-frontend"
    "pixel-perfect"
    "visual-redesign"
  ];
  skillOverlayFile = pkgs.writeText "claude-skill-overlay.json" (
    builtins.toJSON (
      skillDefaultsConfig.mkOverlay {
        configSkillsDir = configDir + "/skills";
        vendoredNames = [
          "humanizer"
          "intent-layer"
          "walkr-author"
          "walkr-tutorial-author"
        ]
        ++ vibecurbSkillNames;
      }
    )
  );
  skillUpdatesConfig = import ./cfg/skill-updates.nix {
    inherit pkgs;
  };
  # NixOS-specific plumbing for the token-optimizer plugin: the FHS interpreter
  # symlink its hook launcher demands, and the config flags that stop it
  # claiming the statusLine slot and self-installing a systemd user unit. Inert
  # unless the plugin is in this host's list (see hasTokenOptimizer below).
  tokenOptimizerConfig = import ./cfg/token-optimizer.nix {
    inherit pkgs;
    homeDir = globals.user.homeDirectory;
  };
  # Context-compression CLI, imperatively `uv tool install`-ed at activation
  # (see cfg/headroom.nix for why it isn't a nix-built derivation). Inert
  # unless cfg.headroom.enable is set on this host.
  headroomConfig = import ./cfg/headroom.nix {
    inherit pkgs versions;
    homeDir = globals.user.homeDirectory;
  };
  fishConfig = import ./cfg/fish.nix {
    inherit
      globals
      pkgs
      statusLineScript
      lib
      hasHeadroom
      ;
  };
  activationConfig = import ./cfg/activation.nix {
    inherit
      pkgs
      lib
      configDir
      statusLineScript
      autoGateScript
      precompactScript
      reinjectScript
      remindersFile
      remindersScript
      gitSyncScript
      guardGeneratedPathsScript
      guardRawNixScript
      guardGitStashScript
      guardPrimaryTreeWriteScript
      guardEnterWorktreeCollisionScript
      guardSecretCommandsScript
      scrubSecretOutputScript
      globals
      homeDir
      ;
    tokenOptimizerActivation = lib.optionalString hasTokenOptimizer tokenOptimizerConfig.activation;
    inherit (pkgs) rtk;
    humanizerSkillSrc = inputs.humanizer-skill;
    # One skill out of a six-skill repo, so this points at the subdirectory
    # rather than the input root.
    intentLayerSkillSrc = inputs.crafter-station-skills + "/context-engineering/intent-layer";
    # walkr-author and walkr-tutorial-author live under skills/ in walkr's own
    # repo, alongside the flake that builds the walkr binary (apps/cli/walkr).
    # Same input, same pin, so the skills and the binary they author content
    # for never drift apart.
    walkrAuthorSkillSrc = inputs.walkr + "/skills/walkr-author";
    walkrTutorialAuthorSkillSrc = inputs.walkr + "/skills/walkr-tutorial-author";
    # VibeCurb design skills -- one input, seven skill directories under
    # skills/. inherit vibecurbSkillNames so activation.nix's symlink loop
    # and this module's skill-overlay vendoredNames list stay in sync.
    vibecurbSkillsSrc = inputs.vibecurb-skills + "/skills";
    inherit vibecurbSkillNames;
    # Reference the rules file by path, not through
    # `config.apps.cli.text-polish.rulesFile`. Reading the option made this
    # module fail to evaluate on any host that imports claude-code without
    # text-polish (srv, #246). The option is readOnly with this exact path as
    # its default, so the two can't drift, and activation only ever `cp`s it.
    textPolishRulesFile = ../text-polish/prompt/concision-rules.md;
    pluginOverlay = pluginOverlayFile;
    skillOverlay = skillOverlayFile;
    userScopeMcpTemplate = userScopeMcpTemplateFile;
    inherit (mcpConfig) secretServerFiles;
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

  # PreToolUse permission gate for /auto and /github-issues-auto autonomous
  # sessions. Sole arbiter for rm/kill/pkill, gated by the session-bound
  # ~/.claude/.auto-mode-active sentinel (see
  # config/skills/auto/references/permission-model.md). rm is further scoped
  # to the session's own working tree (git toplevel of the hook payload's
  # .cwd), an optional pre-authorized-folders file, and a short list of
  # universal scratch roots -- git is needed for the toplevel resolution.
  autoGateScript = pkgs.writeShellApplication {
    name = "claude-auto-gate";
    runtimeInputs = [
      pkgs.jq
      pkgs.gnugrep
      pkgs.coreutils
      pkgs.git
    ];
    text = builtins.readFile ./cfg/scripts/auto-gate.sh;
  };

  # `auto-permissions` on PATH: manages auto-gate.sh's pre-authorized-folders
  # file (~/.claude/auto-safe-roots) and reports sentinel status. Validation
  # rules are a deliberate second copy of auto-gate.sh's own (see the
  # script's header) -- kept as a real writeShellApplication, not a plain
  # writeScriptBin like mcp-pick/skill-pick, because it duplicates
  # permission-sensitive logic that's worth shellcheck + set -e catching a
  # typo in, same reasoning as autoGateScript above.
  autoPermissionsScript = pkgs.writeShellApplication {
    name = "auto-permissions";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = builtins.readFile ./cfg/scripts/auto-permissions.sh;
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

  # SessionStart git-sync (issue: primary-checkout resets clobbering another
  # live session's view of the tree). Reports ahead/behind status everywhere;
  # only auto-`git reset`s a linked worktree, and only when it's clean. Never
  # resets the shared primary checkout (epic #252 invariant 1, same
  # git-dir/git-common-dir check as guardPrimaryTreeWriteScript below).
  gitSyncScript = pkgs.writeShellApplication {
    name = "claude-git-sync";
    runtimeInputs = [
      pkgs.git
      pkgs.coreutils
    ];
    text = builtins.readFile ./cfg/scripts/git-sync.sh;
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

  # Hard PreToolUse deny for agent git writes in the PRIMARY checkout (issue
  # #264, epic #252 invariant 1). Agents work in linked worktrees; the shared
  # primary tree is read-only for them, so a second live session never trips
  # over a dirty tree or a moved HEAD. Denies before the write lands, unlike the
  # warn-level bash-guard in settings.json. The sanctioned /commit and
  # git-cleanup flows opt a single command in with CLAUDE_SANCTIONED_GIT=1.
  # Fails open on ambiguity; a deny can't be overridden by an allow.
  guardPrimaryTreeWriteScript = pkgs.writeShellApplication {
    name = "claude-guard-primary-tree-write";
    runtimeInputs = [
      pkgs.jq
      pkgs.gnugrep
      pkgs.git
      pkgs.coreutils
    ];
    text = builtins.readFile ./cfg/scripts/guard-primary-tree-write.sh;
  };

  # Hard PreToolUse deny for an EnterWorktree(name=...) call that would
  # collide with an existing worktree directory or the branch EnterWorktree
  # itself creates (worktree-<name>). EnterWorktree silently RESUMES on a
  # collision rather than erroring, which breaks the 1:1 worktree:agent
  # guarantee the fish `__claude_worktree_name` launch-time helper
  # (cfg/fish.nix) provides for new spawns; this is the backstop for
  # EnterWorktree called mid-session, which no wrapper script can reach. A
  # path-based EnterWorktree call (deliberate resume) is never denied. Fails
  # open on ambiguity; a deny can't be overridden by an allow.
  guardEnterWorktreeCollisionScript = pkgs.writeShellApplication {
    name = "claude-guard-enter-worktree-collision";
    runtimeInputs = [
      pkgs.jq
      pkgs.git
      pkgs.coreutils
    ];
    text = builtins.readFile ./cfg/scripts/guard-enter-worktree-collision.sh;
  };

  # Hard PreToolUse deny for commands that would print a secret into the
  # transcript (env/printenv dumps, cat of a secrets file, op read, echo of a
  # *_TOKEN var, sf org display --json, curl -v, set -x). Closes the leak class
  # documented in the secret-leak RCA. A deny can't be overridden by an allow,
  # so it holds even though `env`/`cat` remain allow-listed in settings.json.
  guardSecretCommandsScript = pkgs.writeShellApplication {
    name = "claude-guard-secret-commands";
    runtimeInputs = [
      pkgs.jq
      pkgs.gnugrep
      pkgs.coreutils
    ];
    text = builtins.readFile ./cfg/scripts/guard-secret-commands.sh;
  };

  # rtk config (~/.config/rtk/config.toml, deployed via xdg.configFile below).
  # Generated here rather than hand-written because a malformed file degrades
  # SILENTLY: Config::load() propagates the parse error, but get_rewritten() in
  # rtk's src/hooks/hook_cmd.rs swallows it with unwrap_or_default(), so a typo
  # drops every exclusion and quietly starts wrapping the 1Password recipes with
  # no signal. Verified on 0.43.0: against a truncated exclude_commands array
  # `rtk hook check` still proposes the rewrite, while `rtk config` reports the
  # parse error. Only [hooks] is pinned; [tee], [telemetry] and [tracking] are
  # deliberately left at the pinned rtk's own defaults.
  #
  # The two `just` patterns and the `op` pattern are defensive, not load-bearing.
  # Neither `just` nor `op` is in rtk's hook-rewrite registry as of 0.43.0, so
  # rtk proposes no rewrite for those commands with or without this file, and
  # the patterns exclude candidates that do not exist. They stay as insurance
  # against a later rtk teaching itself either binary. `just` does have an
  # output filter, but that only applies to an explicit `rtk just ...`. Re-check
  # after a nixpkgs bump with `rtk hook check '<cmd>'`, the dry-run the hook
  # engine itself runs: "No rewrite for: <cmd>" on stderr means rtk either does
  # not know the command or is excluding it here, and a printed `rtk ...` line
  # means it would wrap it. `rtk rewrite` is not a substitute, because it prints
  # on stdout for identity rewrites too, so an already-wrapped `rtk git status`
  # echoes itself back and reads as a hit. Two just patterns because `just`
  # takes either the short alias or the full recipe name; the name pattern has
  # no trailing anchor so it still catches fetch-gmailctl-creds-for, whose
  # keyword sits mid-name. Alternation order inside a pattern means nothing:
  # exclude_commands is a boolean is_match and Rust's regex engine matches
  # whatever the branch order.
  #
  # The path pattern is the one that actually fires. rtk DOES rewrite cat, head,
  # tail, grep, rg, find, ls, wc, git, gh, kubectl and docker among others, and
  # tee runs in "failures" mode, so a failed read of a secrets file would
  # otherwise land unfiltered under ~/.local/share/rtk/tee/. The alternation
  # mirrors the path list in guard-secret-commands.sh rule 3, minus that rule's
  # `.pub` negative lookahead, which Rust's regex crate has no syntax for.
  # Excluding id_*.pub along with the private keys costs nothing.
  #
  # The leading `^` is required. A pattern that does not already start with `^`
  # gets escaped and anchored to command start, so a bare 'nixos-secrets' leaves
  # `cat /tmp/nixos-secrets/f.json` rewritten while '^.*nixos-secrets' excludes
  # it. That same rule dictates where the case flag goes: the guard greps with
  # -i, so the path pattern needs `^(?i).*` to fold case the same way, whereas a
  # leading `(?i)` would demote the whole pattern to an escaped literal and
  # disable the exclusion outright. Verified against the 0.43.0 binary.
  #
  # `share/rtk/tee/` tracks rtk's default tee location, which is NOT pinned
  # here because `[tee] directory` takes no portable value. A relative path
  # resolves against the caller's cwd, `~` goes unexpanded (rtk creates a
  # literal `~` directory), only an absolute path works, all four sibling keys
  # turn mandatory once the section exists, and RTK_TEE_DIR overrides the config
  # regardless. Setting either one means moving this literal and the matching
  # one in guard-secret-commands.sh.
  #
  # Known upstream gap, same binary: the numeric shorthand forms `head -5 F`,
  # `tail -3 F` and `head --lines=5 F` skip the exclusion check entirely. Even a
  # catch-all '^.*' exclusion leaves them rewritten, so no pattern here can
  # close it. `head F` and `head -n 5 F` are excluded correctly. The
  # guard-secret-commands deny hook still covers the shorthand forms.
  #
  # TOML *literal* strings (single quotes) get no escape processing, so \s
  # reaches the regex engine as written. Basic strings would need \\s.
  rtkConfigFile = pkgs.writeText "rtk-config.toml" ''
    [hooks]
    exclude_commands = [
      '^just (rs|ps|cs|fs|rot|fgc)($|\s)',
      '^just [a-z-]*(secret|op-token|cred|signature)',
      '^op($|\s)',
      '^(?i).*(secrets\.json|nixos-secrets|service-account-token|/\.config/op/|credentials\.json|share/rtk/tee/|\.ssh/id_)',
    ]
  '';

  # PostToolUse output scrubber: redacts secret values (literal values from
  # secrets.json + known token-shaped prefixes) from a Bash tool's stdout/stderr
  # before the model sees it, via the `updatedToolOutput` rewrite mechanism. The
  # last-line-of-defense net behind guard-secret-commands.sh.
  scrubSecretOutputScript = pkgs.writeShellApplication {
    name = "claude-scrub-secret-output";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = builtins.readFile ./cfg/scripts/scrub-secret-output.sh;
  };

  # Shell scripts -- read from files, substitute placeholders
  k8s-mcp-setup = builtins.replaceStrings [ "@KUBECONFIG_FILE@" ] [ kubeconfigFile ] (
    builtins.readFile ./cfg/scripts/k8s-mcp-setup.fish
  );

  mcpPick = builtins.readFile ./cfg/scripts/mcp-pick.bash;

  # Same fzf-picker pattern as mcp-pick, but for skills: skills ship on by
  # default in every project (unlike MCP servers, which are opt-in via
  # mcp-pick), so this toggles OFF exceptions per project instead of building
  # an include set from nothing. Writes skillOverrides into the project's
  # .claude/settings.local.json, merged in -- not a wholesale overwrite, since
  # that file also carries permission rules and other local state.
  skillPick = builtins.readFile ./cfg/scripts/skill-pick.bash;

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

  hasTokenOptimizer = lib.elem tokenOptimizerConfig.pluginId cfg.plugins;

  # Not a plugin-list membership test like the two above -- headroom has no
  # marketplace entry, so it gets its own enable option (see the options
  # block below).
  hasHeadroom = cfg.headroom.enable;

  # Conditional env vars exported into both system and HM session scopes.
  # Built once here so the two consumer sites can't drift.
  #
  # Secret-bearing tokens (GEMINI_API_KEY, AHA_API_TOKEN, WAVE_FULL_ACCESS_TOKEN)
  # are NOT set here: exporting them via environment.variables/sessionVariables
  # bakes the plaintext into the world-readable Nix store. They are exported at
  # shell runtime by the fish module, read from the off-store secrets file
  # (issue #265). Only non-secret env vars remain below.
  claudeEnv =
    lib.optionalAttrs hasHyperframes {
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
      enable = lib.mkEnableOption "claude-code CLI tool with custom configuration";
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
      headroom.enable = lib.mkEnableOption ''
        Headroom (headroomlabs-ai/headroom), a local context-compression CLI
        installed via `uv tool install` at activation (see cfg/headroom.nix
        for why -- it's a PyPI-only package with heavy optional ML extras,
        not a nix-built derivation). Adds the `headroom` binary to PATH and
        an opt-in `hclaude` fish function ("claude, wrapped by headroom");
        it does not change what plain `claude` does.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Keep the global CLAUDE.md thin (#294): it deploys verbatim to
    # ~/.claude/CLAUDE.md and is re-sent on every turn, so an unbounded
    # regrowth silently erodes the token-budget win that issue fixed. Trips
    # at eval time (any `just build-host` / `just qr`) rather than waiting
    # for the next transcript audit to notice. The 8000 ceiling matches
    # #294's own target exactly rather than leaving slack, so the file
    # currently sits within ~200 bytes of it -- the next addition to this
    # file should come with an equivalent trim, not a threshold bump.
    assertions = [
      {
        assertion = builtins.stringLength (builtins.readFile (configDir + "/CLAUDE.md")) < 8000;
        message = "modules/apps/cli/claude-code/config/CLAUDE.md must stay under 8000 characters (see #294); it is currently ${
          toString (builtins.stringLength (builtins.readFile (configDir + "/CLAUDE.md")))
        }.";
      }
    ];

    # System packages for MCP tooling and LSP servers
    environment.systemPackages =
      (with pkgs; [
        (writeScriptBin "mcp-pick" mcpPick)
        (writeScriptBin "skill-pick" skillPick)
        autoPermissionsScript
        llm-agents.claude-plugins # Plugin & skills manager
        fzf
        jq
        rsync # used by claude-capture + activation to mirror skills

        # The intent-layer skill's estimate_tokens.sh formats its result with
        # `bc`, under `set -e`, so a missing bc aborts the script on any
        # directory over 1k estimated tokens -- i.e. every real one. Not in the
        # default NixOS toolchain, so it has to be named. Unconditional because
        # intent-layer itself is (see cfg/activation.nix), unlike the
        # plugin-gated extras below.
        bc

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

    # Puppeteer env vars only applied when the hyperframes plugin is enabled --
    # keeps the system environment clean on hosts that don't use it.
    # `claudeEnv` (see `let` block) builds this attrset once; reused below
    # for `home.sessionVariables` so the two scopes can't drift.
    environment.variables = claudeEnv;

    # The only part of token-optimizer that cannot be done from home-manager:
    # its hook launcher hardcodes an interpreter allow-list of FHS prefixes and
    # /usr/local is root-owned. See cfg/token-optimizer.nix for why there is no
    # env-var route around it.
    systemd.tmpfiles.rules = lib.optionals hasTokenOptimizer tokenOptimizerConfig.tmpfilesRules;

    home-manager.users.${globals.user.name} = {
      programs.fish = fishConfig;

      home = {
        sessionVariables = claudeEnv;
        packages =
          (with pkgs; [
            llm-agents.claude-code
            # Output-compression proxy. Installed per-user, not in
            # environment.systemPackages, because its state (tee logs, learned
            # command stats) lives under ~/.local/share/rtk/.
            rtk
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
          ++ skillUpdatesConfig.packages;

        # `uv tool install` (cfg/headroom.nix) writes the `headroom` shim to
        # ~/.local/bin. dev.python already puts that dir on PATH when it's
        # enabled, but claude-code doesn't depend on dev.python, so add it
        # here too rather than silently relying on another module's opt-in.
        # Order-independent: a duplicate entry from both modules is harmless.
        sessionPath = lib.optionals hasHeadroom [ "${homeDir}/.local/bin" ];

        # Copy config files as writable copies via activation script.
        # This replaces programs.claude-code.{settings,memory,agents,skills,outputStyles}
        # so that Claude Code can modify its own config at runtime.
        activation = {
          claudeCodeConfig = inputs.home-manager.lib.hm.dag.entryAfter [
            "writeBoundary"
          ] activationConfig.text;
        }
        // lib.optionalAttrs hasHeadroom {
          headroomInstall = inputs.home-manager.lib.hm.dag.entryAfter [
            "writeBoundary"
          ] headroomConfig.activation;
        };

        # Preserve per-server files for mcp-pick workflow compatibility.
        file = mcpConfig.files // lspConfig.files // contextsConfig.files;
      };

      # rtk reads this with a plain exists/read/parse and no trust gate
      # (src/core/config.rs), so a read-only store symlink is fine here. No line
      # numbers: the source is pinned only through nixpkgs and would rot.
      # rtk's *filter* files are different -- those are SHA-trust-gated and would
      # be silently skipped -- but we ship none of those.
      xdg.configFile = {
        "rtk/config.toml".source = rtkConfigFile;
      };
    };
  };
}
