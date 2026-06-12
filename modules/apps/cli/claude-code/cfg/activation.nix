{
  pkgs,
  configDir,
  statusLineScript,
  reapConfig,
  globals,
  homeDir,
  humanizerSkillSrc,
  pluginOverlay,
}:

{
  text = ''
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

      # Plugin surface is owned by Nix (cfg/plugin-config.nix), not by the
      # captured settings.json. Merge the SHA-pinned extraKnownMarketplaces and
      # the enabledPlugins map in here so they can't drift via capture.
      ${pkgs.jq}/bin/jq --slurpfile ov ${pluginOverlay} \
        '.extraKnownMarketplaces = $ov[0].extraKnownMarketplaces
         | .enabledPlugins = $ov[0].enabledPlugins' \
        "$claude_home/settings.json" > "$claude_home/settings.json.tmp"
      mv "$claude_home/settings.json.tmp" "$claude_home/settings.json"
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
    #
    # If a previous activation left a stale symlink (e.g. directly into the
    # Nix store), remove it first -- rsync would otherwise try to write through
    # the symlink and fail with EROFS on the read-only store target.
    for skill_dir in "${configDir}"/skills/*/; do
      skill_name="$(basename "$skill_dir")"
      if [ -L "$claude_home/skills/$skill_name" ]; then
        $DRY_RUN_CMD rm -f "$claude_home/skills/$skill_name"
      fi
      $DRY_RUN_CMD mkdir -p "$claude_home/skills/$skill_name"
      $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -a --delete --chmod=u+w \
        "$skill_dir" "$claude_home/skills/$skill_name/"
    done

    # Humanizer skill -- pinned to upstream blader/humanizer via the
    # `humanizer-skill` flake input. Symlink (not rsync) so the file stays
    # read-only and claude-capture auto-skips the top-level symlink check
    # in cfg/fish.nix. Update via `nix flake update humanizer-skill`.
    $DRY_RUN_CMD rm -rf "$claude_home/skills/humanizer"
    $DRY_RUN_CMD ln -snf "${humanizerSkillSrc}" "$claude_home/skills/humanizer"

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

    # Plugins -- known_marketplaces.json and enabledPlugins are owned
    # declaratively (cfg/plugin-config.nix, merged into settings.json above);
    # Claude Code reconciles the marketplace registry + installs at session
    # start. We still deploy two runtime files that have no settings.json
    # equivalent:
    #
    #   installed_plugins.json -- seeds the install record so an already-cached
    #     host shows plugins without a re-install round-trip. SHA-stamped, so it
    #     is captured (cfg/fish.nix) rather than authored.
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
          rm -f "$claude_home/plugins/installed_plugins.json"
          ${pkgs.gnused}/bin/sed 's|@HOME_DIR@|${homeDir}|g' \
            "$plugins_src/installed_plugins.json" > "$claude_home/plugins/installed_plugins.json"
          chmod 644 "$claude_home/plugins/installed_plugins.json"
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
