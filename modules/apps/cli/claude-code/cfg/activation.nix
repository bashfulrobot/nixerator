{
  pkgs,
  lib,
  configDir,
  statusLineScript,
  precompactScript,
  reinjectScript,
  remindersFile,
  remindersScript,
  gitSyncScript,
  guardGeneratedPathsScript,
  guardRawNixScript,
  globals,
  homeDir,
  serverProfile,
  humanizerSkillSrc,
  walkrAuthorSkillSrc,
  walkrTutorialAuthorSkillSrc,
  textPolishRulesFile,
  pluginOverlay,
  stackPermissions,
  stackAutoMode,
  skillOverlay,
  secretServerFiles,
  secretsFile,
  # claude-skills owns the declared settings keys and the two shared files when
  # this is true (apps.cli.claude-code.stackApply.enable). False keeps the jq
  # merge below, byte for byte. See .claude/docs/claude-stack-apply.md.
  stackApply,
  stackApplyScript,
  stackVarsFile,
  claudeSkillsSrc,
  stackHost,
  # JSON array of the plugin ids this host's resolved claude-stack manifest
  # declares with a state other than "absent". Only read with stackApply on,
  # where it filters the captured installed_plugins.json down to this host.
  installedPluginsKeepFile,
}:

let
  # Nix-owned hook clauses, as jq assignments over ~/.claude/settings.json.
  # Each one is idempotent: it drops any existing entry carrying its command
  # marker, then appends the current store path.
  #
  # Split out of the shell body because which clauses apply depends on
  # stackApply, and a jq program assembled from lib.optionalString inline in a
  # heredoc is unreadable.
  #
  # dk >= 3.6.0 ships the PreCompact checkpoint and the UserPromptSubmit
  # re-inject as plugin hooks, so with stackApply on they are stripped here and
  # never re-appended: two copies would write the recovery file twice and print
  # the hard rules twice. The nixerator scripts stay in cfg/scripts/ until
  # phase 8. SessionStart (reminders, git-sync) has no plugin equivalent and is
  # injected in both modes.
  stripCompactionHooks = ''
    .hooks.PreCompact = ((.hooks.PreCompact // [])
        | map(select((.hooks[0].command // "") | test("claude-precompact-checkpoint") | not)))
    | .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // [])
        | map(select((.hooks[0].command // "") | test("claude-post-compact-reinject") | not)))
  '';
  injectCompactionHooks = ''
    .hooks.PreCompact = (((.hooks.PreCompact // [])
        | map(select((.hooks[0].command // "") | test("claude-precompact-checkpoint") | not)))
        + [{hooks: [{type: "command", command: "${precompactScript}/bin/claude-precompact-checkpoint"}]}])
    | .hooks.UserPromptSubmit = (((.hooks.UserPromptSubmit // [])
        | map(select((.hooks[0].command // "") | test("claude-post-compact-reinject") | not)))
        + [{hooks: [{type: "command", command: "${reinjectScript}/bin/claude-post-compact-reinject"}]}])
  '';
  injectSessionStartHooks = ''
    .hooks.SessionStart = (((.hooks.SessionStart // [])
        | map(select((.hooks[0].command // "") | test("claude-session-reminders") | not)))
        + [{hooks: [{type: "command", command: "${remindersScript}/bin/claude-session-reminders"}]}])
    | .hooks.SessionStart = (((.hooks.SessionStart // [])
        | map(select((.hooks[0].command // "") | test("claude-git-sync|\\[git-sync\\]") | not)))
        + [{matcher: "startup", hooks: [{type: "command", command: "${gitSyncScript}/bin/claude-git-sync"}]}])
  '';
  # These guards ship in the dk plugin (hooks/hooks.json); drop the copies an
  # earlier generation injected with nix store paths so each guard does not run
  # twice. `bin/rtk hook claude` is an older retired tool's entry.
  stripPreToolUseHooks = ''
    .hooks.PreToolUse = (((.hooks.PreToolUse // [])
        | map(select((.hooks[0].command // "") | test("bin/rtk hook claude") | not))
        | map(select((.hooks[0].command // "") | test("claude-guard-(git-stash|primary-tree-write|enter-worktree-collision|secret-commands)") | not))))
  '';
  # Only without stackApply. With it on, the manifest's `linux` profile
  # declares both as @GUARD_GENERATED_PATHS_HOOK@ and @GUARD_RAW_NIX_HOOK@ and
  # apply replaces hooks.PostToolUse whole, so appending them here would
  # duplicate them; the scrub strip is redundant for the same reason.
  injectPostToolUseHooks = ''
    .hooks.PostToolUse = (((.hooks.PostToolUse // [])
        | map(select((.hooks[0].command // "") | test("claude-guard-generated-paths|claude-guard-raw-nix") | not)))
        + [{matcher: "Edit|Write|MultiEdit", hooks: [{type: "command", command: "${guardGeneratedPathsScript}/bin/claude-guard-generated-paths"}]},
           {matcher: "Bash", hooks: [{type: "command", command: "${guardRawNixScript}/bin/claude-guard-raw-nix"}]}])
    | .hooks.PostToolUse = ((.hooks.PostToolUse // [])
        | map(select((.hooks[0].command // "") | test("claude-scrub-secret-output") | not)))
  '';
  hooksFilter = lib.concatStringsSep "| " (
    (if stackApply then [ stripCompactionHooks ] else [ injectCompactionHooks ])
    ++ [
      injectSessionStartHooks
      stripPreToolUseHooks
    ]
    ++ lib.optional (!stackApply) injectPostToolUseHooks
  );
in

{
  text = ''
    claude_home="${homeDir}/.claude"

    # Create directories
    $DRY_RUN_CMD mkdir -p "$claude_home/agents"
    $DRY_RUN_CMD mkdir -p "$claude_home/skills"
    $DRY_RUN_CMD mkdir -p "$claude_home/output-styles"

    # CLAUDE.md -- global instructions.
    #
    # With stackApply on, the manifest's `files` section owns this path and
    # apply writes it from claude-skills (one copy for NixOS and the Mac), so
    # this copy is skipped rather than written and immediately overwritten.
    # config/CLAUDE.md stays in the repo until phase 8 of the central-config
    # plan deletes it; see .claude/docs/claude-stack-apply.md.
    ${lib.optionalString (!stackApply) ''
      $DRY_RUN_CMD rm -f "$claude_home/CLAUDE.md"
      $DRY_RUN_CMD cp --no-preserve=mode "${configDir}/CLAUDE.md" "$claude_home/CLAUDE.md"
    ''}

    # reminders.json -- Nix-rendered maintenance-reminder registry (cfg/reminders.nix),
    # read at SessionStart by claude-session-reminders.
    $DRY_RUN_CMD rm -f "$claude_home/reminders.json"
    $DRY_RUN_CMD cp --no-preserve=mode "${remindersFile}" "$claude_home/reminders.json"

    # settings.json -- substitute statusline store path
    # Remove first in case it's a stale symlink into the nix store (read-only)
    if [ -z "$DRY_RUN_CMD" ]; then
      rm -f "$claude_home/settings.json"
      ${pkgs.gnused}/bin/sed \
        -e 's|@STATUSLINE_COMMAND@|${statusLineScript}/bin/claude-statusline|g' \
        -e 's|@USER_NAME@|${globals.user.name}|g' \
        -e 's|@HOME_DIR@|${globals.user.homeDirectory}|g' \
        "${configDir}/settings.json" > "$claude_home/settings.json"

      # SSH_AUTH_SOCK for env.SSH_AUTH_SOCK -- injected here (not a source
      # placeholder) because settings.json's `env` block takes only literal
      # strings: Claude Code performs zero shell/env expansion on it, so a
      # prior `"''${XDG_RUNTIME_DIR}/gcr/ssh"` literal never resolved and
      # background/bwrap-sandboxed sessions (which don't inherit systemd's
      # user-environment import, hence don't get home.sessionVariables
      # either) fell back to the raw passphrase-protected SSH key.
      #
      # XDG_RUNTIME_DIR is set alongside it on purpose. The Bash tool's shell
      # sources /etc/set-environment, which runs
      # `export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"`. With
      # XDG_RUNTIME_DIR empty (background sessions) that rewrites the correct
      # value above to the literal `/gcr/ssh`. Giving every tool process the
      # real runtime dir makes that export resolve to the same socket.
      #
      # Resolved with a real `id -u` here, at real activation time on the
      # real host -- not at Nix eval time, which can run cross-host (see
      # `just build-host`) and would bake in the wrong UID.
      #
      # With stackApply on, apply re-forces env.XDG_RUNTIME_DIR from the same
      # `id -u` (cfg/scripts/stack-apply.sh computes the @XDG_RUNTIME_DIR@
      # value), so the two agree and this clause is left as the only writer of
      # SSH_AUTH_SOCK, which the manifest declares nowhere.
      #
      # serverProfile == "minimal" (srv) has no gcr-ssh-agent: its agent
      # socket comes from `keychain` (hosts/srv/home.nix) and gets a fresh
      # random path on every ssh-agent (re)start, so it can never be a safe
      # static value here -- baking today's path would just go silently
      # stale after the next reboot. Delete the key there instead of setting
      # one that's wrong most of the time: Claude Code then falls through to
      # whatever SSH_AUTH_SOCK the launching shell already had, which is
      # correct for interactive sessions (keychain's fish init already
      # exports it) and leaves background sessions exactly as unfixed as
      # today, never worse.
      ${
        if serverProfile == "minimal" then
          ''
            ${pkgs.jq}/bin/jq --arg rt "/run/user/$(id -u)" \
              'del(.env.SSH_AUTH_SOCK) | .env.XDG_RUNTIME_DIR = $rt' \
              "$claude_home/settings.json" > "$claude_home/settings.json.tmp"
            mv "$claude_home/settings.json.tmp" "$claude_home/settings.json"
          ''
        else
          ''
            ${pkgs.jq}/bin/jq --arg rt "/run/user/$(id -u)" \
              '.env.XDG_RUNTIME_DIR = $rt | .env.SSH_AUTH_SOCK = ($rt + "/gcr/ssh")' \
              "$claude_home/settings.json" > "$claude_home/settings.json.tmp"
            mv "$claude_home/settings.json.tmp" "$claude_home/settings.json"
          ''
      }

      # Plugin surface is owned by Nix (cfg/plugin-config.nix), not by the
      # captured settings.json. Merge the SHA-pinned extraKnownMarketplaces and
      # the enabledPlugins map in here so they can't drift via capture.
      ${pkgs.jq}/bin/jq --slurpfile ov ${pluginOverlay} \
        '.extraKnownMarketplaces = $ov[0].extraKnownMarketplaces
         | .enabledPlugins = $ov[0].enabledPlugins' \
        "$claude_home/settings.json" > "$claude_home/settings.json.tmp"
      mv "$claude_home/settings.json.tmp" "$claude_home/settings.json"

      # permissions.allow, both modes, in scripts/activation-allow.jq (covered
      # by cfg/scripts/tests/activation-allow.bats, which holds the per-mode
      # reasoning):
      #
      #   stackApply off -- add-only ordered union of the claude-stack
      #     snapshot's rules into the runtime-owned live list. Capture
      #     (cfg/fish.nix) keeps the key, so appended rules round-trip into the
      #     repo copy and stay a fixpoint.
      #   stackApply on  -- the block the sed above copied out of
      #     config/settings.json is dropped, and apply (further down, the last
      #     writer) puts the manifest's resolved list there instead. Nothing
      #     re-adds a repo-side block on top of it.
      #
      # config/settings.json keeps its 158-rule block, which phase 8 deletes and
      # nothing before that, and capture leaves it alone. So on a stackApply
      # host the 99 rules the manifest does not declare stop reaching
      # ~/.claude at the next rebuild, and `claude_stack.py promote` in
      # claude-skills is how one of them is kept. An empty manifest list is an
      # eval-time assertion failure (default.nix), not an empty allow list.
      # See .claude/docs/claude-stack-apply.md.
      ${pkgs.jq}/bin/jq -f ${./scripts/activation-allow.jq} \
        --argjson stack_apply ${lib.boolToString stackApply} \
        --slurpfile decl ${stackPermissions} \
        "$claude_home/settings.json" > "$claude_home/settings.json.tmp"
      mv "$claude_home/settings.json.tmp" "$claude_home/settings.json"

      # autoMode (auto-mode classifier rules) from the claude-stack snapshot:
      # Nix-owned, so REPLACED here, unlike the add-only permissions above.
      # Each list the manifest declares for this host is set wholesale, which
      # is what lets a narrowed rule in claude-skills actually remove the old
      # broad one. A key the manifest leaves empty keeps whatever the base
      # settings.json carries, and a host that declares nothing is untouched.
      # Capture (cfg/fish.nix) strips the key, so edits made through
      # /auto-mode-setup only persist once they are in the claude-skills
      # manifest. Idempotent: the same file produces the same result.
      ${pkgs.jq}/bin/jq --slurpfile am ${stackAutoMode} \
        '.autoMode = ((.autoMode // {}) + ($am[0] | with_entries(select(.value | length > 0))))' \
        "$claude_home/settings.json" > "$claude_home/settings.json.tmp"
      mv "$claude_home/settings.json.tmp" "$claude_home/settings.json"

      # Default-off skill surface (cfg/skill-defaults.nix) is Nix-owned the
      # same way: force-set at user scope so a captured runtime edit can't
      # drift it. skill-pick's per-project "on" entries live in a different
      # file entirely (.claude/settings.local.json) and are unaffected --
      # the settings cascade resolves each skill name independently, so a
      # project opt-in still wins over this default.
      ${pkgs.jq}/bin/jq --slurpfile sk ${skillOverlay} \
        '.skillOverrides = $sk[0].skillOverrides' \
        "$claude_home/settings.json" > "$claude_home/settings.json.tmp"
      mv "$claude_home/settings.json.tmp" "$claude_home/settings.json"

      # The /auto permission gate now ships in the dk plugin (hooks/hooks.json,
      # PreToolUse Bash). Pin the ask list, and drop any auto-gate hook entry
      # an earlier generation injected with a nix store path, so the gate does
      # not run twice (the dk plugin owns it).
      #
      # With stackApply on the manifest forces permissions.ask, so only the
      # stale-entry strip is left here.
      ${pkgs.jq}/bin/jq \
        '${
          lib.optionalString (!stackApply) ".permissions.ask = [\"Bash(sudo *)\"] | "
        }.hooks.PreToolUse = ((.hooks.PreToolUse // [])
             | map(select((.hooks[0].command // "") | test("claude-auto-gate") | not)))' \
        "$claude_home/settings.json" > "$claude_home/settings.json.tmp"
      mv "$claude_home/settings.json.tmp" "$claude_home/settings.json"

      # Context-rot, reminder, and hardened-guard hooks are Nix-owned, same as
      # the hooks above: injected here with their store paths and stripped on
      # capture (cfg/fish.nix strips any hook whose command lives under /nix/store,
      # so a new injected hook needs NO capture-side change). The clauses are
      # assembled in the `let` block at the top of this file, because stackApply
      # changes which of them run.
      ${pkgs.jq}/bin/jq \
        '${hooksFilter}' \
        "$claude_home/settings.json" > "$claude_home/settings.json.tmp"
      mv "$claude_home/settings.json.tmp" "$claude_home/settings.json"
      ${lib.optionalString stackApply ''

        # claude-skills owns the declared settings keys from here on: one
        # `claude_stack.py apply --write` call in place of the jq force-merge
        # this module used to carry for model, outputStyle, statusLine, env,
        # permissions.{allow,deny,ask,defaultMode,additionalDirectories},
        # hooks.PostToolUse and the UI and telemetry flags, plus the two shared
        # files (CLAUDE.md, statusline.sh). Nix contributes only @VAR@ values:
        # the statusline wrapper's store path, the four Nix-built hook store
        # paths, the ten hook bodies read out of config/settings.json,
        # env.PATH, and the runtime dir the wrapper resolves from a real
        # `id -u`.
        #
        # It runs AFTER the clauses above, which is also why nothing is
        # re-appended here any more. The manifest now declares all four hook
        # events it owns (PostToolUse, SessionStart, UserPromptSubmit, Stop),
        # and apply forces each of those lists whole, so the inject clauses
        # above only matter with stackApply off. hooks.PreToolUse and
        # hooks.PreCompact are not declared, so the strip clauses above still
        # carry.
        #
        # SSH_AUTH_SOCK stays host-owned (set or deleted above by
        # serverProfile); the manifest deliberately declares no value for it.
        ${stackApplyScript}/bin/claude-stack-apply \
          ${claudeSkillsSrc} ${stackHost} ${stackVarsFile} "$claude_home"
      ''}
      chmod 644 "$claude_home/settings.json"
    else
      $DRY_RUN_CMD "would substitute @STATUSLINE_COMMAND@ in settings.json"
    fi

    # Agents -- remove stale symlinks before copying
    for agent in "${configDir}"/agents/*.md; do
      $DRY_RUN_CMD rm -f "$claude_home/agents/$(basename "$agent")"
      $DRY_RUN_CMD cp --no-preserve=mode "$agent" "$claude_home/agents/$(basename "$agent")"
    done

    # Retired agents -- the loop above only copies, so a removed source file
    # leaves its live copy behind. slack-search listed the disabled Slack MCP
    # tools; dk:slack-search (dk plugin) replaces it.
    $DRY_RUN_CMD rm -f "$claude_home/agents/slack-search.md"

    # Skills -- mirror each Nix-managed skill into ~/.claude/skills/<skill>/
    # using rsync. --delete prunes anything removed from source.
    # --chmod=u+w makes files writable so Claude Code can edit them at runtime
    # (Nix store content is read-only otherwise).
    #
    # If a previous activation left a stale symlink (e.g. directly into the
    # Nix store), remove it first -- rsync would otherwise try to write through
    # the symlink and fail with EROFS on the read-only store target.
    #
    # config/skills/ can be empty of skill directories (everything ships from a
    # plugin now); with no match the glob stays literal, so skip a non-directory
    # instead of mkdir-ing a skill named "*".
    for skill_dir in "${configDir}"/skills/*/; do
      [ -d "$skill_dir" ] || continue
      skill_name="$(basename "$skill_dir")"
      if [ -L "$claude_home/skills/$skill_name" ]; then
        $DRY_RUN_CMD rm -f "$claude_home/skills/$skill_name"
      fi
      $DRY_RUN_CMD mkdir -p "$claude_home/skills/$skill_name"
      $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -a --delete --chmod=u+w \
        "$skill_dir" "$claude_home/skills/$skill_name/"
    done

    # Sweep up directory shells left behind by a skill deletion. Deleting a
    # skill from the repo is propagated to ~/.claude by capture-sync, which
    # runs before this activation on every `just qr`: repo-side gone plus
    # home-side untouched is its `delete-home` action, and it unlinks the
    # files. What it does not do is remove the now-empty directories, because
    # it reconciles files, not trees.
    #
    # Deliberately empty-only, and deliberately not provenance-aware. When
    # capture-sync finds the home copy was EDITED after the repo deleted it, it
    # raises a conflict and leaves the files in place for `just claude-resolve`
    # to settle. A prune here that removed any skill missing from the repo
    # would delete exactly the copy that conflict was protecting, one activation
    # later, before the user ever saw the prompt. An empty directory has no
    # SKILL.md, so it is invisible to the skill listing and safe to remove no
    # matter who created it.
    #
    # -depth -empty -delete collapses leaves first, so references/ going empty
    # lets its parent go too on the same pass.
    $DRY_RUN_CMD ${pkgs.findutils}/bin/find "$claude_home/skills" \
      -mindepth 1 -depth -type d -empty -delete 2>/dev/null || true

    # text-polish skill -- install the shared concision-rules file into its
    # references. This is the SAME file the SUPER+SHIFT+R keybind filter reads
    # (single source of truth in the text-polish module), copied in after the
    # rsync --delete above so it survives. Editing the source moves both.
    #
    # 2026-09-08: text-polish moved out of config/skills/ into
    # dk@claude-skills, so the rsync loop above no longer creates
    # $claude_home/skills/text-polish and this `if` is now permanently
    # false -- left as a no-op rather than deleted, since it costs nothing
    # and the keybind filter is unaffected either way (it reads
    # textPolishRulesFile directly, not through this copy; see
    # modules/apps/cli/text-polish/default.nix). The marketplace skill's own
    # references/concision-rules.md is a separate file this can't patch.
    if [ -d "$claude_home/skills/text-polish" ]; then
      $DRY_RUN_CMD mkdir -p "$claude_home/skills/text-polish/references"
      $DRY_RUN_CMD cp --no-preserve=mode "${textPolishRulesFile}" \
        "$claude_home/skills/text-polish/references/concision-rules.md"
    fi

    # Humanizer skill: 2026-09-08, stopped symlinking the flake-vendored
    # copy here. dk@claude-skills (cfg/plugin-config.nix) now depends on the
    # same upstream (blader/humanizer) as an installed plugin, so this
    # symlink would only have produced a second, source-drifting "humanizer"
    # skill next to the plugin-provided one. humanizerSkillSrc/the
    # humanizer-skill flake input are left in place, unused by this script,
    # in case a fallback to the Nix-pinned copy is ever needed again.

    # intent-layer skill: 2026-10-26, stopped symlinking the flake-vendored
    # copy and dropped the `crafter-station-skills` input with it. The name
    # resolved to nothing Dustin uses: no CLAUDE.md rule, no skill, no plugin
    # and no script referenced it, and the manifest's skillOverrides had it
    # off on every host. The symlink was the only reason the input existed.
    # Decision recorded as A9 in claude-skills
    # docs/plans/personal-vs-upstream-assessment.md.

    # walkr-author / walkr-tutorial-author skills: 2026-09-09, stopped
    # symlinking the flake-vendored copy here, matching the humanizer
    # retirement above -- same reasoning applied a day later. dk@claude-skills
    # ships both under the same names now. This one carried a real trade-off
    # the humanizer retirement didn't: this copy was pinned to the exact same
    # rev as the walkr binary (apps/cli/walkr, same `walkr` flake input), so
    # the skill text and the renderer's actual content-format contract could
    # never drift apart; the plugin's copy has no such guarantee. Retired
    # anyway, on the explicit call that every machine should source these
    # skills the same way -- donkeykong (this user's non-Nix machine) already
    # runs this exact trade: its Gofile installs `walkr@latest` unpinned and
    # gets the skills from dk@claude-skills alone, with a comment
    # acknowledging the binary and the skill copies "want bumping together"
    # with no mechanism enforcing it. This machine now accepts the same risk
    # instead of being the one host that's different. walkrAuthorSkillSrc /
    # walkrTutorialAuthorSkillSrc and the `walkr` flake input itself are left
    # in place -- the input still builds the walkr binary, unrelated to this
    # symlink loop -- unused here now, in case a fallback is ever needed
    # again. See cfg/skill-defaults.nix's `extraOff` for how these two stay
    # default-off (skill-pick opt-in) the way they always were, now that
    # they're no longer tracked in allVendoredSkillNames.

    # VibeCurb design skills: 2026-10-26, stopped symlinking the seven
    # flake-vendored copies and dropped the `vibecurb-skills` input with
    # them, matching the humanizer and walkr retirements above. The
    # `vibecurb` plugin in claude-skills ships all seven under the same
    # names, and `cmp` was silent on all seven pairs, so the symlinks were a
    # second byte-identical copy that could only drift. They stay default-off
    # through cfg/skill-defaults.nix's `extraOff`, the same mechanism the
    # walkr pair uses. Decision recorded as A10 in claude-skills
    # docs/plans/personal-vs-upstream-assessment.md.
    #
    # Nothing is removed from ~/.claude/skills by this change: the loop that
    # created the symlinks is gone, not replaced with one that deletes them.
    # The seven stale links are removed by hand on qbert, listed in
    # .claude/docs/vendored-skills.md.

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

    # kong-konnect comes from the kong-konnect@claude-skills plugin on every
    # host, so a user-scope `kong-konnect` entry in ~/.claude.json (registered
    # by earlier generations of this module) would shadow the plugin's server.
    # Delete it. ~/.claude.json is runtime-owned and holds unrelated state, so
    # only that one key is touched, and only when present; a failed jq leaves
    # the file as it was.
    claude_json="${homeDir}/.claude.json"
    if [ -z "$DRY_RUN_CMD" ] && [ -f "$claude_json" ]; then
      if ${pkgs.jq}/bin/jq -e '.mcpServers["kong-konnect"] // empty' "$claude_json" >/dev/null 2>&1; then
        if ${pkgs.jq}/bin/jq 'del(.mcpServers["kong-konnect"])' "$claude_json" > "$claude_json.tmp"; then
          chmod 600 "$claude_json.tmp"
          mv "$claude_json.tmp" "$claude_json"
        else
          echo "claude-code: failed to remove kong-konnect from $claude_json, leaving it unchanged" >&2
          rm -f "$claude_json.tmp"
        fi
      fi
    fi

    # Secret-bearing MCP servers (tableau): their
    # .mcp.json is written here at 0600 from the off-store secrets file, so the
    # real token never lands in the world-readable store (issue #265). The
    # placeholdered template lives in the store; each @TOKEN@ is replaced with
    # the runtime value. Substitution runs through jq, so the value is escaped
    # into the JSON string context (a value containing a quote or backslash can
    # never produce malformed JSON), and jq reads the value with `--rawfile`
    # from a 0600 temp so it never shows in `ps`. The placeholder tokens contain
    # no regex metacharacters, so the `gsub` match is exact.
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: sf: ''
        if [ -z "$DRY_RUN_CMD" ] && [ -f "${secretsFile}" ]; then
          mcp_dir="$claude_home/mcp-servers/${name}"
          mkdir -p "$mcp_dir"
          (
            umask 077
            cp --no-preserve=mode ${pkgs.writeText "mcp-${name}.json.tpl" sf.json} "$mcp_dir/.mcp.json.tmp"
            ${lib.concatMapStringsSep "\n" (s: ''
              if ${pkgs.jq}/bin/jq -e '${s.path} // empty' "${secretsFile}" >/dev/null 2>&1; then
                ${pkgs.jq}/bin/jq -j '${s.path}' "${secretsFile}" > "$mcp_dir/.val"
                ${pkgs.jq}/bin/jq --rawfile val "$mcp_dir/.val" \
                  '(.. | strings) |= gsub("${s.placeholder}"; $val)' \
                  "$mcp_dir/.mcp.json.tmp" > "$mcp_dir/.mcp.json.tmp2"
                mv "$mcp_dir/.mcp.json.tmp2" "$mcp_dir/.mcp.json.tmp"
                rm -f "$mcp_dir/.val"
              fi
            '') sf.subs}
            chmod 600 "$mcp_dir/.mcp.json.tmp"
            mv "$mcp_dir/.mcp.json.tmp" "$mcp_dir/.mcp.json"
          )
        fi
      '') secretServerFiles
    )}

    # Plugins -- known_marketplaces.json and enabledPlugins are owned
    # declaratively (cfg/plugin-config.nix, merged into settings.json above);
    # Claude Code reconciles the marketplace registry + installs at session
    # start. We still deploy two runtime files that have no settings.json
    # equivalent:
    #
    #   installed_plugins.json -- seeds the install record so an already-cached
    #     host shows plugins without a re-install round-trip. SHA-stamped, so it
    #     is captured (cfg/fish.nix) rather than authored. Captured on qbert, so
    #     with stackApply on it is filtered per host before it is written: see
    #     cfg/scripts/filter-installed-plugins.jq for what the unfiltered copy
    #     did to srv.
    #   blocklist.json         -- managed plugin blocklist.
    #
    # The plugin cache itself is not tracked; Claude Code re-downloads from the
    # pinned marketplace SHAs on first use.
    plugins_src="${configDir}/plugins"
    if [ -d "$plugins_src" ]; then
      $DRY_RUN_CMD mkdir -p "$claude_home/plugins"

      # installed_plugins.json -- substitute @HOME_DIR@ placeholder
      if [ -f "$plugins_src/installed_plugins.json" ]; then
        if [ -z "$DRY_RUN_CMD" ]; then
          ${
            if stackApply then
              ''
                # Written through a temp so a corrupt repo copy cannot replace a
                # good deployed record: jq exits nonzero on anything that is not
                # a JSON object, and the file already there is left alone.
                ip_dest="$claude_home/plugins/installed_plugins.json"
                ip_tmp="$ip_dest.tmp"
                if ${pkgs.gnused}/bin/sed 's|@HOME_DIR@|${homeDir}|g' \
                     "$plugins_src/installed_plugins.json" \
                   | ${pkgs.jq}/bin/jq -f ${./scripts/filter-installed-plugins.jq} \
                       --slurpfile keep ${installedPluginsKeepFile} > "$ip_tmp"; then
                  chmod 644 "$ip_tmp"
                  mv "$ip_tmp" "$ip_dest"
                else
                  rm -f "$ip_tmp"
                  echo "warning: ${configDir}/plugins/installed_plugins.json did not parse as a JSON object; left $ip_dest as it was" >&2
                fi
              ''
            else
              ''
                rm -f "$claude_home/plugins/installed_plugins.json"
                ${pkgs.gnused}/bin/sed 's|@HOME_DIR@|${homeDir}|g' \
                  "$plugins_src/installed_plugins.json" > "$claude_home/plugins/installed_plugins.json"
                chmod 644 "$claude_home/plugins/installed_plugins.json"
              ''
          }
        fi
      fi

      # blocklist.json -- plain copy
      if [ -f "$plugins_src/blocklist.json" ]; then
        $DRY_RUN_CMD rm -f "$claude_home/plugins/blocklist.json"
        $DRY_RUN_CMD cp --no-preserve=mode "$plugins_src/blocklist.json" "$claude_home/plugins/blocklist.json"
      fi
    fi
  '';
}
