{
  globals,
  pkgs,
  statusLineScript,
}:

{
  functions = {
    # Wrapper that offers to clean up project .mcp.json on exit
    claude = {
      wraps = "claude";
      body = ''
        command claude $argv
        set -l exit_code $status
        if test -f .mcp.json
            read -P "Remove .mcp.json from this project? [y/N] " confirm
            if string match -qi 'y*' -- $confirm
                rm .mcp.json
                echo "Removed .mcp.json"
            end
        end
        return $exit_code
      '';
    };

    # Read-only Q&A -- pipe-friendly headless helper
    ask = {
      description = "Ask Claude a question (read-only tools, pipe-friendly)";
      body = ''
        set -l prompt (string join " " $argv)
        if not isatty stdin
          set input (cat)
          claude -p "$prompt\n\n$input" --allowedTools "Read,Bash,Glob,Grep"
        else
          claude -p $prompt --allowedTools "Read,Bash,Glob,Grep"
        end
      '';
    };

    # Capture runtime Claude config back to the Nix source tree
    claude-capture = {
      description = "Capture ~/.claude config changes back to Nix source tree";
      body = ''
        set -l config_dir "${globals.paths.nixerator}/modules/apps/cli/claude-code/config"
        set -l claude_dir "$HOME/.claude"
        set -l statusline_pattern "${statusLineScript}/bin/claude-statusline"

        if not test -d "$config_dir"
          echo "Error: config directory not found at $config_dir"
          return 1
        end

        echo "Capturing Claude Code config to Nix source tree..."
        echo ""

        # settings.json -- replace statusline store path back to placeholder
        if test -f "$claude_dir/settings.json"
          sed "s|$statusline_pattern|@STATUSLINE_COMMAND@|g" "$claude_dir/settings.json" \
            | jq . > "$config_dir/settings.json"
          echo "  settings.json"
        end

        # CLAUDE.md
        if test -f "$claude_dir/CLAUDE.md"
          cp "$claude_dir/CLAUDE.md" "$config_dir/CLAUDE.md"
          echo "  CLAUDE.md"
        end

        # Agents -- capture all user-managed agents (skip gsd-* managed by
        # GSD). If an agent isn't in config/agents/ yet, seed it so
        # manual work survives a machine rebuild. Agents listed in
        # config/agents/.capture-ignore are silently skipped -- use for
        # plugin-provided or upstream-maintained agents.
        set -l agents_ignore_file "$config_dir/agents/.capture-ignore"
        set -l ignored_agents
        if test -f "$agents_ignore_file"
          for line in (cat "$agents_ignore_file")
            set -l trimmed (string trim -- "$line")
            if test -n "$trimmed"; and not string match -q '#*' -- "$trimmed"
              set ignored_agents $ignored_agents $trimmed
            end
          end
        end
        set -l seeded_agents
        echo "  agents:"
        for agent in $claude_dir/agents/*.md
          set -l name (basename $agent)
          if string match -q 'gsd-*' $name
            continue
          end
          if contains -- "$name" $ignored_agents
            continue
          end
          set -l marker ""
          if not test -f "$config_dir/agents/$name"
            set seeded_agents $seeded_agents $name
            set marker " (seeded)"
          end
          cp "$agent" "$config_dir/agents/$name"
          echo "    $name$marker"
        end

        # Skills -- capture every user-managed skill from $claude_dir/skills/
        # into config/skills/ using rsync. Guiding principle: anything
        # manually added to ~/.claude is captured into the repo so it
        # survives a machine rebuild and can be deployed to other systems.
        # A skill not yet in config/skills/ is seeded on first capture.
        # Skills listed in config/skills/.capture-ignore are silently
        # skipped -- use for upstream-maintained or externally-managed
        # skills that shouldn't live in git history.
        # Silently skips:
        #   - whole-skill symlinks (Nix-managed, e.g. clay-ralph)
        #   - runtime workspaces with no SKILL.md (commit-workspace, etc.)
        #   - plugin-managed skills whose every leaf is a symlink into
        #     /nix/store (hack, dependabot, stop-slop, github-issue)
        # Top-level symlinks in tracked skills are --exclude'd from rsync
        # so a store path never lands in git.
        set -l skills_ignore_file "$config_dir/skills/.capture-ignore"
        set -l ignored_skills
        if test -f "$skills_ignore_file"
          for line in (cat "$skills_ignore_file")
            set -l trimmed (string trim -- "$line")
            if test -n "$trimmed"; and not string match -q '#*' -- "$trimmed"
              set ignored_skills $ignored_skills $trimmed
            end
          end
        end
        set -l seeded_skills
        echo "  skills:"
        for source_dir in $claude_dir/skills/*/
          set -l skill_name (basename $source_dir)
          set -l src "$claude_dir/skills/$skill_name"
          # Skip entire-skill symlinks (Nix-managed).
          if test -L "$src"
            continue
          end
          # Skip runtime workspaces -- real skills have a SKILL.md marker.
          if not test -e "$src/SKILL.md"
            continue
          end
          # Skip plugin-managed skills (no real files anywhere, all symlinks).
          set -l any_real (${pkgs.findutils}/bin/find "$src" -mindepth 1 \
            -not -type d -not -type l -print -quit 2>/dev/null)
          if test -z "$any_real"
            continue
          end
          # Skip anything the user opted out of tracking.
          if contains -- "$skill_name" $ignored_skills
            continue
          end
          # Untracked: seed it so the user's work is captured.
          set -l marker ""
          if not test -d "$config_dir/skills/$skill_name"
            mkdir -p "$config_dir/skills/$skill_name"
            set seeded_skills $seeded_skills $skill_name
            set marker " (seeded)"
          end
          # Mirror src → config, excluding any Nix-managed symlinks.
          set -l excludes
          for f in $src/*
            if test -L "$f"
              set -l name (basename $f)
              set excludes $excludes "--exclude=/$name"
            end
          end
          ${pkgs.rsync}/bin/rsync -a --delete $excludes \
            "$src"/ "$config_dir/skills/$skill_name"/
          echo "    $skill_name$marker"
        end

        # Output styles
        echo "  output-styles:"
        for style in $claude_dir/output-styles/*
          if not test -L "$style"
            set -l name (basename $style)
            cp "$style" "$config_dir/output-styles/$name"
            echo "    $name"
          end
        end

        # Plugins
        set -l plugins_dir "$claude_dir/plugins"
        set -l plugins_config "$config_dir/plugins"
        if test -f "$plugins_dir/installed_plugins.json"
          echo "  plugins:"
          mkdir -p "$plugins_config"

          # installed_plugins.json -- replace $HOME with placeholder
          sed "s|$HOME|@HOME_DIR@|g" "$plugins_dir/installed_plugins.json" \
            | jq . > "$plugins_config/installed_plugins.json"
          echo "    installed_plugins.json"

          # known_marketplaces.json -- replace $HOME with placeholder
          if test -f "$plugins_dir/known_marketplaces.json"
            sed "s|$HOME|@HOME_DIR@|g" "$plugins_dir/known_marketplaces.json" \
              | jq . > "$plugins_config/known_marketplaces.json"
            echo "    known_marketplaces.json"
          end

          # blocklist.json -- plain copy
          if test -f "$plugins_dir/blocklist.json"
            cp "$plugins_dir/blocklist.json" "$plugins_config/blocklist.json"
            echo "    blocklist.json"
          end

          # Cache is not tracked in git -- plugins auto-download from installed_plugins.json
        end

        # Surface seeded items so nothing sneaks into git unnoticed.
        if test (count $seeded_agents) -gt 0 -o (count $seeded_skills) -gt 0
          echo ""
          echo "Seeded items (new in repo, review and git add):"
          for a in $seeded_agents
            echo "    agent:  $a"
          end
          for s in $seeded_skills
            echo "    skill:  $s"
          end
        end

        echo ""
        echo "Done. Review changes with: git diff $config_dir"
      '';
    };
  };

  # Fish abbreviations
  shellAbbrs = {
    cc = {
      position = "command";
      setCursor = true;
      expansion = "claude -p \"%\"";
    };
  };
}
