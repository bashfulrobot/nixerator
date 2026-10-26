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
      ;
    inherit (cfg) serverProfile;
  };
  contextsConfig = import ./cfg/contexts.nix {
    inherit lib;
    inherit (mcpConfig) mcpServers;
  };
  lspConfig = import ./cfg/lsp-plugins.nix { inherit lib; };
  # Declarative, SHA-pinned plugin surface, derived from the claude-stack
  # manifest snapshot for cfg.stackHost (cfg/claude-stack/<host>.json, copied
  # from bashfulrobot/claude-skills by the pin-bump script). The overlay is the
  # { extraKnownMarketplaces, enabledPlugins } object merged into settings.json
  # at activation (and stripped from capture so Nix owns these keys).
  # pluginConfig.enabled is the list of plugin ids this host enables, used by
  # the plugin-gated extras below.
  # True once Dustin flips the switch per host: claude-skills owns the declared
  # settings keys, the resolved host file comes from the flake input instead of
  # the hand-copied snapshot, and activation makes one `claude_stack.py apply`
  # call. False is the pre-existing behaviour, byte for byte. Switch-on and
  # rollback steps: .claude/docs/claude-stack-apply.md.
  stackApply = cfg.stackApply.enable;
  claudeSkillsSrc = inputs.claude-skills;

  pluginConfig = import ./cfg/plugin-config.nix {
    inherit lib;
    inherit (cfg) stackHost;
    claudeSkillsSrc = if stackApply then claudeSkillsSrc else null;
    claudeSkillsRev = if stackApply then (claudeSkillsSrc.rev or null) else null;
  };
  pluginOverlayFile = pkgs.writeText "claude-plugin-overlay.json" (
    builtins.toJSON pluginConfig.overlay
  );
  # Manifest permissions.allow for this host, unioned (add-only) into
  # settings.json at activation. Unlike the overlay, the key is runtime-owned.
  stackPermissionsFile = pkgs.writeText "claude-stack-permissions.json" (
    builtins.toJSON pluginConfig.permissionsAllow
  );
  # Manifest autoMode rules for this host, force-set into settings.json at
  # activation (the whole key is Nix-owned and stripped from capture).
  stackAutoModeFile = pkgs.writeText "claude-stack-automode.json" (
    builtins.toJSON pluginConfig.autoMode
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
  # Every symlinked-skill name Nix installs, vibecurb's seven plus the
  # pre-existing ones. Single source of truth for the skill-overlay call
  # below and the collision assertion further down -- both need the exact
  # same list.
  #
  # "humanizer" dropped 2026-09-08, "walkr-author" / "walkr-tutorial-author"
  # dropped 2026-09-09: dk@claude-skills (cfg/plugin-config.nix) ships all
  # three now (humanizer as an installed-plugin dependency on the same
  # upstream, blader/humanizer; walkr-author/walkr-tutorial-author as its
  # own skills), so the flake-vendored symlinks (cfg/activation.nix) were
  # retired rather than shipping two copies of each. This machine, not just
  # donkeykong (this user's non-Nix machine, which never had a vendored
  # copy to begin with) now accepts the same trade the walkr binary's own
  # Gofile entry there already documents: the skill copy and the walkr
  # binary version can drift apart, and that's fine. walkr-author and
  # walkr-tutorial-author were default-off before this (they were never in
  # skill-defaults.nix's alwaysOn) -- since they're no longer in
  # allVendoredSkillNames, mkOverlay's
  # extraOff below is what keeps them default-off rather than silently
  # flipping to Claude Code's absent-key-means-on default.
  allVendoredSkillNames = [
    "intent-layer"
  ]
  ++ vibecurbSkillNames;
  # Same directory-listing computation skill-defaults.nix's mkOverlay does
  # internally for configSkillsDir, duplicated here only because mkOverlay
  # doesn't expose its intermediate configNames and the collision assertion
  # below needs it too.
  configSkillNames = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir (configDir + "/skills"))
  );
  skillOverlayFile = pkgs.writeText "claude-skill-overlay.json" (
    builtins.toJSON (
      skillDefaultsConfig.mkOverlay {
        configSkillsDir = configDir + "/skills";
        vendoredNames = allVendoredSkillNames;
        # Preserves the pre-2026-09-09 default-off behavior for two skills
        # that used to reach this default through allVendoredSkillNames
        # membership (see the comment there): once a skill's source is
        # claude-skills only, mkOverlay has no way to know it exists at all,
        # so it can no longer land in offNames on its own.
        extraOff = [
          "walkr-author"
          "walkr-tutorial-author"
        ];
      }
    )
  );
  skillUpdatesConfig = import ./cfg/skill-updates.nix {
    inherit pkgs;
  };
  # Context-compression CLI, imperatively `uv tool install`-ed at activation
  # (see cfg/headroom.nix for why it isn't a nix-built derivation). Inert
  # unless cfg.headroom.enable is set on this host.
  headroomConfig = import ./cfg/headroom.nix {
    inherit pkgs versions;
    homeDir = globals.user.homeDirectory;
  };
  # Clone + build of the kong-docs-rag plugin's backing binary (see
  # cfg/kong-docs-rag.nix). Inert unless cfg.kongDocsRag.enable is set.
  kongDocsRagConfig = import ./cfg/kong-docs-rag.nix {
    inherit pkgs;
    homeDir = globals.user.homeDirectory;
  };
  fishConfig = import ./cfg/fish.nix {
    inherit
      globals
      pkgs
      statusLineScript
      lib
      hasHeadroom
      stackApply
      ;
  };
  activationConfig = import ./cfg/activation.nix {
    inherit
      pkgs
      lib
      configDir
      statusLineScript
      precompactScript
      reinjectScript
      remindersFile
      remindersScript
      gitSyncScript
      guardGeneratedPathsScript
      guardRawNixScript
      globals
      homeDir
      ;
    inherit (cfg) serverProfile;
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
    stackPermissions = stackPermissionsFile;
    stackAutoMode = stackAutoModeFile;
    skillOverlay = skillOverlayFile;
    inherit (mcpConfig) secretServerFiles;
    inherit secretsFile;
    inherit stackApply claudeSkillsSrc;
    inherit (cfg) stackHost;
    stackApplyScript = stackApplyScriptPkg;
    stackVarsFile = stackVarsFilePkg;
    stackNixOnlyPostToolUse = stackNixOnlyPostToolUseFile;
  };

  # --- claude-skills apply (apps.cli.claude-code.stackApply.enable) ---------
  #
  # The one wrapper activation calls. python3 runs claude_stack.py (standard
  # library only), jq builds the @VAR@ values file, coreutils supplies mktemp
  # and id.
  stackApplyScriptPkg = pkgs.writeShellApplication {
    name = "claude-stack-apply";
    runtimeInputs = [
      pkgs.python3
      pkgs.jq
      pkgs.coreutils
    ];
    text = builtins.readFile ./cfg/scripts/stack-apply.sh;
  };

  # The repo settings.json, read at eval time. Two things come out of it: the
  # `nix fmt` hook body the manifest declares as @NIX_FMT_HOOK@, and the
  # PostToolUse rows the manifest does not declare at all.
  repoSettings = builtins.fromJSON (builtins.readFile (configDir + "/settings.json"));
  repoPostToolUse = repoSettings.hooks.PostToolUse or [ ];
  rowCommand = row: (builtins.head row.hooks).command or "";
  # The one row claude-skills' `linux` profile declares as @NIX_FMT_HOOK@, with
  # the same matcher and the same async flag. Passing the existing command
  # through as a var keeps the deployed hook byte-identical to today's, so
  # turning stackApply on changes nothing about it.
  nixFmtRows = lib.filter (r: lib.hasInfix ''nix fmt "$file"'' (rowCommand r)) repoPostToolUse;
  # Rows that have a home elsewhere: the nix-fmt row above, and the
  # default-branch warning that dk >= 3.6.0 ships as warn-default-branch.sh.
  # The `Bash` row that also mentions origin/HEAD warns on git commit/push and
  # has no plugin equivalent, hence the matcher test.
  isRehomedRow =
    r:
    lib.hasInfix ''nix fmt "$file"'' (rowCommand r)
    || (
      r.matcher or "" == "Edit|Write|MultiEdit" && lib.hasInfix "refs/remotes/origin/HEAD" (rowCommand r)
    );
  # Everything else is a NixOS-only check with no manifest row yet. apply
  # replaces hooks.PostToolUse as one list, so activation re-appends these
  # after it (cfg/activation.nix). Deletable in phase 8, once each one is
  # either a dk hook or a declared manifest row.
  stackNixOnlyPostToolUse = lib.filter (r: !isRehomedRow r) repoPostToolUse;
  stackNixOnlyPostToolUseFile = pkgs.writeText "claude-stack-nix-only-posttooluse.json" (
    builtins.toJSON stackNixOnlyPostToolUse
  );

  # @VAR@ values for the `vars` the claude-skills `linux` profile declares
  # (claude-stack/resolved/<host>.json). XDG_RUNTIME_DIR is deliberately absent:
  # cfg/scripts/stack-apply.sh adds it from a real `id -u` at activation time,
  # because Nix eval can run cross-host.
  stackVars = {
    LINUX_PATH = "/run/wrappers/bin:/etc/profiles/per-user/${globals.user.name}/bin:/run/current-system/sw/bin";
    STATUSLINE_COMMAND = "${statusLineScript}/bin/claude-statusline";
    NIX_FMT_HOOK = rowCommand (lib.head nixFmtRows);
    GUARD_GENERATED_PATHS_HOOK = "${guardGeneratedPathsScript}/bin/claude-guard-generated-paths";
    GUARD_RAW_NIX_HOOK = "${guardRawNixScript}/bin/claude-guard-raw-nix";
  };
  stackVarsFilePkg = pkgs.writeText "claude-stack-vars.json" (builtins.toJSON stackVars);

  # The CLAUDE.md the manifest's `files` section deploys. Only read when
  # stackApply is on, and only after pathExists says it is there.
  stackSharedClaudeMd = claudeSkillsSrc + "/claude-stack/files/CLAUDE.md";

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
  # git-dir/git-common-dir check the dk plugin's guard-primary-tree-write uses).
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
  hasHyperframes = lib.elem "hyperframes@hyperframes" pluginConfig.enabled;
  hyperframesBrowserPath = "/run/current-system/sw/bin/${globals.preferences.browser}";

  # Not a plugin-list membership test like the two above -- headroom has no
  # marketplace entry, so it gets its own enable option (see the options
  # block below).
  hasHeadroom = cfg.headroom.enable;

  # Conditional env vars exported into both system and HM session scopes.
  # Built once here so the two consumer sites can't drift.
  #
  # Secret-bearing tokens (GEMINI_API_KEY, AHA_API_TOKEN, WAVE_FULL_ACCESS_TOKEN)
  # are NOT set here: exporting them via environment.variables/sessionVariables
  # bakes the plaintext into the world-readable Nix store, and no shell exports
  # them either. Each consumer reads its value from the secauto gopass store at
  # run time (see "No exported API tokens" in extras/docs/secrets.md). Only
  # non-secret env vars remain below.
  claudeEnv =
    lib.optionalAttrs hasHyperframes {
      PUPPETEER_EXECUTABLE_PATH = hyperframesBrowserPath;
      PUPPETEER_SKIP_DOWNLOAD = "1";
    }
    // lib.optionalAttrs (lib.attrByPath [ "apps" "gui" "insync" "enable" ] false config) {
      # dk's wave-invoicing skill reads the Camino invoices folder from
      # $WAVE_INSYNC_ROOT (per host, never in the repo). This is the path the
      # retired config/skills/wave-invoicing/config.json carried as
      # customers.camino.insync_root. Only hosts that run Insync have it.
      # attrByPath, not config.apps.gui.insync.enable: headless hosts (srv)
      # have no apps.gui options at all and the direct access fails to eval.
      WAVE_INSYNC_ROOT = "${homeDir}/insync/bashfulrobot/My-drive/Professional/Consulting/Camino-corp/Financial/Invoices";
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
      stackHost = lib.mkOption {
        type = lib.types.str;
        default = config.networking.hostName;
        defaultText = lib.literalExpression "config.networking.hostName";
        description = ''
          Which claude-stack snapshot (cfg/claude-stack/<host>.json, a copy of
          claude-skills' claude-stack/resolved/<host>.json) drives this host's
          plugins and marketplaces. Defaults to the hostname; override when a
          host should follow another host's declared stack. Replaces the old
          per-module `plugins` list option: plugin membership now lives only in
          the claude-skills manifest.
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
      stackApply.enable = lib.mkEnableOption ''
        claude-skills as the source of truth for the Claude Code settings.

        On: activation makes one `claude_stack.py apply --write` call (via
        cfg/scripts/stack-apply.sh) in place of the jq force-merge in
        cfg/activation.nix, cfg/plugin-config.nix reads the resolved host file
        out of the `claude-skills` flake input instead of the hand-copied
        cfg/claude-stack/ snapshot, the manifest's `files` section writes
        ~/.claude/CLAUDE.md and ~/.claude/statusline.sh, and the capture pass
        (cfg/fish.nix) stops carrying the manifest-owned keys back into the
        repo.

        Off (the default): every one of those keeps its pre-stackApply
        behaviour, byte for byte, so merging the change that introduced this
        option deploys nothing new. Turn it on per host, and re-lock the
        claude-skills input first -- the pinned rev must be one whose manifest
        declares the `settings`, `files` and `vars` sections.

        Switch-on checklist and the settings.json.nix-backup rollback:
        .claude/docs/claude-stack-apply.md
      '';
      kongDocsRag.enable = lib.mkEnableOption ''
        Provision the checkout and binary behind the kong-docs-rag plugin
        (kong-docs-rag@claude-skills): clone bashfulrobot/kong-docs-rag to
        ~/git/kong-docs-rag and `go build` bin/kong-docs-rag at activation
        when missing (cfg/kong-docs-rag.nix). Also installs a systemd user
        timer (daily 06:00) that runs `git pull --ff-only`, rebuilds when the
        checkout moved, then `bin/kong-docs-rag index -data-dir data`; it is
        skipped while the binary is missing and tolerates Ollama being down.
        Does not set the plugin's repo_path config; that stays manual
      '';
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
      {
        # cfg/activation.nix interpolates vibecurbSkillNames, unquoted, into a
        # shell `for skill in ${...}; do rm -rf "$claude_home/skills/$skill"; ...;
        # done` loop. A name with a space splits into extra iterations, one
        # with a glob character expands at the `for` line, and one with `/`
        # or `..` escapes ~/.claude/skills entirely -- all of that lands in an
        # `rm -rf` under $HOME. Every current entry is a safe literal; this
        # guards the next one.
        assertion = lib.all (
          n: builtins.match "[A-Za-z0-9._-]+" n != null && n != "." && n != ".."
        ) vibecurbSkillNames;
        message = "vibecurbSkillNames (default.nix) must be plain path-safe names (no spaces, globs, or path separators) -- cfg/activation.nix interpolates this list unquoted into a shell loop that feeds `rm -rf`. Got: ${toString vibecurbSkillNames}.";
      }
      {
        # `ln -snf` succeeds even when its target is missing, so a typo here
        # or an upstream rename at the next `vibecurb-skills` rev bump would
        # otherwise activate cleanly and just leave a dangling symlink --
        # the skill silently stops existing with no build-time signal.
        assertion = lib.all (
          n: builtins.pathExists (inputs.vibecurb-skills + "/skills/" + n)
        ) vibecurbSkillNames;
        message = "vibecurbSkillNames (default.nix) lists a name with no matching skills/<name> directory in the pinned vibecurb-skills rev -- check the name against that rev's skills/ listing before bumping the input.";
      }
      {
        # activation.nix rsyncs config/skills/* first, then the vendored-skill
        # symlink pairs (including the vibecurb loop) rm -rf whatever is at
        # that path and replace it. A same-named repo skill would be silently
        # shadowed on every rebuild with no warning.
        assertion = lib.intersectLists allVendoredSkillNames configSkillNames == [ ];
        message = "A vendored skill name (default.nix's allVendoredSkillNames) collides with a repo-owned skill under config/skills/ -- activation.nix's rm -rf/ln -snf pass would silently delete and replace the repo copy on every rebuild. Rename one side.";
      }
      {
        # @NIX_FMT_HOOK@ is one declared manifest row, so exactly one repo row
        # may claim it. Zero means a rename made `lib.head` throw with no
        # explanation; two means the var would silently take the first.
        assertion = lib.length nixFmtRows == 1;
        message = "claude-code: config/settings.json must hold exactly one PostToolUse hook whose command runs `nix fmt \"$file\"` (it becomes the @NIX_FMT_HOOK@ value the claude-skills manifest declares); found ${toString (lib.length nixFmtRows)}.";
      }
    ]
    ++ lib.optionals stackApply [
      {
        # A row that is neither re-homed nor re-appended would be dropped
        # silently by apply's forced hooks.PostToolUse. Pin the count so a
        # change to config/settings.json has to be looked at.
        assertion = lib.length stackNixOnlyPostToolUse == 6;
        message = "claude-code: stackApply re-appends the PostToolUse hooks the claude-skills manifest does not declare, and expects 6 of them in config/settings.json; found ${toString (lib.length stackNixOnlyPostToolUse)}. Either a hook moved to the dk plugin or the manifest (add it to default.nix's isRehomedRow), or a new NixOS-only hook was added (bump this count).";
      }
      {
        # The pinned rev must be one whose manifest carries the `files`
        # section. Checked as a path, not read, so a stale pin reports this
        # instead of a bare "file does not exist" from the size check below.
        assertion = builtins.pathExists stackSharedClaudeMd;
        message = "claude-code: stackApply is on but the pinned claude-skills rev has no claude-stack/files/CLAUDE.md, so its manifest predates the settings/files/vars sections apply needs. Run `just update claude-skills`.";
      }
      {
        # The same ceiling as the repo copy above, applied to the file apply
        # actually deploys. Without it the thin-CLAUDE.md budget stops being
        # enforced the moment claude-skills owns the file.
        assertion =
          !(builtins.pathExists stackSharedClaudeMd)
          || builtins.stringLength (builtins.readFile stackSharedClaudeMd) < 8000;
        message = "claude-skills' claude-stack/files/CLAUDE.md must stay under 8000 characters (see #294); the pinned rev has ${toString (builtins.stringLength (builtins.readFile stackSharedClaudeMd))}.";
      }
    ];

    # System packages for MCP tooling and LSP servers
    environment.systemPackages =
      (with pkgs; [
        (writeScriptBin "mcp-pick" mcpPick)
        (writeScriptBin "skill-pick" skillPick)
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

    home-manager.users.${globals.user.name} = {
      programs.fish = fishConfig;

      # Daily kong-docs-rag re-index (cfg/kong-docs-rag.nix).
      systemd.user = lib.mkIf cfg.kongDocsRag.enable kongDocsRagConfig.systemdUser;

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
        // lib.optionalAttrs cfg.kongDocsRag.enable {
          kongDocsRagProvision = inputs.home-manager.lib.hm.dag.entryAfter [
            "writeBoundary"
          ] kongDocsRagConfig.activation;
        }
        // lib.optionalAttrs hasHeadroom {
          headroomInstall = inputs.home-manager.lib.hm.dag.entryAfter [
            "writeBoundary"
          ] headroomConfig.activation;
        };

        # Preserve per-server files for mcp-pick workflow compatibility.
        file = mcpConfig.files // lspConfig.files // contextsConfig.files;
      };
    };
  };
}
