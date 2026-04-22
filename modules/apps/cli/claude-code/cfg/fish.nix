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

        # Agents (skip gsd-* files, those are managed by GSD)
        echo "  agents:"
        for agent in $claude_dir/agents/*.md
          set -l name (basename $agent)
          if not string match -q 'gsd-*' $name
            if test -f "$config_dir/agents/$name"
              cp "$agent" "$config_dir/agents/$name"
              echo "    $name"
            else
              echo "    $name (skipped, not in config/agents/)"
            end
          end
        end

        # Skills -- mirror tracked skills from $claude_dir/skills/<skill>/ into
        # config/skills/<skill>/ using rsync. Iterates what's installed in
        # $claude_dir so we can flag orphans (installed but not in config/).
        # Silently skips:
        #   - whole-skill symlinks (Nix-managed, e.g. clay-ralph)
        #   - runtime workspaces with no SKILL.md (commit-workspace, etc.)
        #   - plugin-managed skills whose every leaf is a symlink into
        #     /nix/store (hack, dependabot, stop-slop, github-issue)
        # Top-level symlinks in tracked skills are --exclude'd from rsync
        # so a store path never lands in git.
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
          # Untracked: surface for visibility, don't import.
          if not test -d "$config_dir/skills/$skill_name"
            echo "    $skill_name (skipped, not in config/skills/)"
            continue
          end
          # Tracked: mirror src → config, excluding any Nix-managed symlinks.
          set -l excludes
          for f in $src/*
            if test -L "$f"
              set -l name (basename $f)
              set excludes $excludes "--exclude=/$name"
            end
          end
          ${pkgs.rsync}/bin/rsync -a --delete $excludes \
            "$src"/ "$config_dir/skills/$skill_name"/
          echo "    $skill_name"
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
