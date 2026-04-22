{
  globals,
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

        # Skills (only dirs that already exist in config/skills/, skip symlinks)
        echo "  skills:"
        for skill_dir in $config_dir/skills/*/
          set -l skill_name (basename $skill_dir)
          set -l source_dir "$claude_dir/skills/$skill_name"
          if test -d "$source_dir"; and not test -L "$source_dir"
            # Remove config subdirs that no longer exist in source
            for existing in $config_dir/skills/$skill_name/*/
              set -l subname (basename $existing)
              if not test -e "$source_dir/$subname"
                rm -rf "$existing"
                echo "    $skill_name/$subname (removed, no longer in source)"
              end
            end
            # Copy files and dirs, but skip any symlinks inside
            for f in $source_dir/*
              if not test -L "$f"
                set -l dest "$config_dir/skills/$skill_name/"(basename $f)
                if test -d "$f"
                  # Wipe and recreate, then cp -rT so dest is treated as the target
                  # itself (prevents nested dest/basename/ when dest already exists).
                  rm -rf "$dest"
                  mkdir -p "$dest"
                  cp -rT "$f" "$dest"
                else
                  cp "$f" "$dest"
                end
                echo "    $skill_name/"(basename $f)
              end
            end
          end
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
