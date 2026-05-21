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

    # Capture runtime Claude config back to the Nix source tree.
    #
    # Most surfaces (skills, agents, output-styles, top-level CLAUDE.md)
    # flow through capture-sync.py, which keeps a sha256 snapshot of
    # every tracked file at $config_dir/.capture-state.json and refuses
    # to blindly overwrite either side. Without that snapshot (the old
    # behaviour), a clean local main checkout that just merged a skill
    # PR would have its repo content clobbered by the still-stale
    # ~/.claude copy on the next `just qr`. The 3-way diff catches that
    # case as "repo was updated, mirror to home" instead.
    #
    # settings.json and the plugin JSONs still flow through the legacy
    # placeholder-substitution path here because the captured content
    # diverges from the home content by design (statusline store path,
    # @HOME_DIR@).
    claude-capture = {
      description = "Capture ~/.claude config changes back to Nix source tree";
      body = ''
        set -l config_dir "${globals.paths.nixerator}/modules/apps/cli/claude-code/config"
        set -l claude_dir "$HOME/.claude"
        set -l statusline_pattern "${statusLineScript}/bin/claude-statusline"
        set -l state_file "$config_dir/.capture-state.json"
        set -l sync_script "${globals.paths.nixerator}/modules/apps/cli/claude-code/cfg/scripts/capture-sync.py"

        if not test -d "$config_dir"
          echo "Error: config directory not found at $config_dir"
          return 1
        end

        echo "Capturing Claude Code config to Nix source tree..."
        echo ""

        # settings.json -- replace statusline store path back to placeholder.
        if test -f "$claude_dir/settings.json"
          sed "s|$statusline_pattern|@STATUSLINE_COMMAND@|g" "$claude_dir/settings.json" \
            | jq . > "$config_dir/settings.json"
          echo "  settings.json"
        end

        # 3-way sync of skills, agents, output-styles, and top-level CLAUDE.md.
        # capture-sync.py reads / writes $state_file (committed JSON) and
        # respects the same .capture-ignore files the old loop did.
        set -l sync_args \
          --state-file "$state_file" \
          --home-root "$claude_dir" \
          --repo-root "$config_dir" \
          --section all

        # On first run with no snapshot file, allow capture-sync to take a
        # baseline. Bootstrap still refuses to silently resolve a real
        # home/repo divergence; the user must pick a side via
        # `just capture-resolve`.
        if not test -f "$state_file"
          set -a sync_args --bootstrap
        end

        # Run capture-sync with stdout (JSON summary) and stderr (conflict
        # sentinels + warnings) routed to separate temp files. Merging
        # streams with 2>&1 would put JSON key/value lines through the
        # conflict-line filter and produce confusing output.
        set -l sync_stdout (mktemp)
        set -l sync_stderr (mktemp)
        ${pkgs.python3}/bin/python3 $sync_script $sync_args >$sync_stdout 2>$sync_stderr
        set -l sync_status $status

        set -l noop_count 0
        set -l capture_count 0
        set -l mirror_count 0
        set -l import_count 0
        set -l bootstrap_count 0
        set -l refresh_count 0
        set -l delete_count 0
        if test -s "$sync_stdout"
          set noop_count (${pkgs.jq}/bin/jq '[.actions[] | select(.action=="noop")] | length' $sync_stdout 2>/dev/null)
          set capture_count (${pkgs.jq}/bin/jq '[.actions[] | select(.action=="capture")] | length' $sync_stdout 2>/dev/null)
          set mirror_count (${pkgs.jq}/bin/jq '[.actions[] | select(.action=="mirror")] | length' $sync_stdout 2>/dev/null)
          set import_count (${pkgs.jq}/bin/jq '[.actions[] | select(.action=="import")] | length' $sync_stdout 2>/dev/null)
          set bootstrap_count (${pkgs.jq}/bin/jq '[.actions[] | select(.action=="bootstrap")] | length' $sync_stdout 2>/dev/null)
          set refresh_count (${pkgs.jq}/bin/jq '[.actions[] | select(.action=="refresh")] | length' $sync_stdout 2>/dev/null)
          set delete_count (${pkgs.jq}/bin/jq '[.actions[] | select(.action=="delete-home")] | length' $sync_stdout 2>/dev/null)
        end

        echo "  sync (skills / agents / output-styles / CLAUDE.md):"
        echo "    in sync:    $noop_count"
        if test "$capture_count" -gt 0
          echo "    captured:   $capture_count  (home -> repo)"
        end
        if test "$mirror_count" -gt 0
          echo "    mirrored:   $mirror_count  (repo -> home)"
        end
        if test "$import_count" -gt 0
          echo "    imported:   $import_count  (new in home, seeded into repo)"
        end
        if test "$bootstrap_count" -gt 0
          echo "    bootstrap:  $bootstrap_count (repo -> home, no prior snapshot)"
        end
        if test "$refresh_count" -gt 0
          echo "    refreshed:  $refresh_count (snapshot stale, sides matched)"
        end
        if test "$delete_count" -gt 0
          echo "    deleted:    $delete_count  (repo removed file, home cleared)"
        end

        if test $sync_status -ne 0
          echo ""
          echo "  CONFLICTS (capture aborted, neither side changed):"
          ${pkgs.gnugrep}/bin/grep '^CAPTURE_SYNC_CONFLICT ' $sync_stderr \
            | ${pkgs.gnused}/bin/sed 's/^CAPTURE_SYNC_CONFLICT /    /'
          echo ""
          echo "  Resolve with:  just capture-resolve <relpath> --home|--repo"
          echo ""
        end

        # Surface any other stderr (warnings about corrupt state, etc.) so
        # it isn't silently swallowed by the temp-file split above.
        if test -s "$sync_stderr"
          ${pkgs.gnugrep}/bin/grep -v '^CAPTURE_SYNC_CONFLICT ' $sync_stderr >&2; or true
        end

        rm -f $sync_stdout $sync_stderr

        # Plugins -- placeholder substitution, kept on legacy path.
        set -l plugins_dir "$claude_dir/plugins"
        set -l plugins_config "$config_dir/plugins"
        if test -f "$plugins_dir/installed_plugins.json"
          echo "  plugins:"
          mkdir -p "$plugins_config"

          sed "s|$HOME|@HOME_DIR@|g" "$plugins_dir/installed_plugins.json" \
            | jq . > "$plugins_config/installed_plugins.json"
          echo "    installed_plugins.json"

          if test -f "$plugins_dir/known_marketplaces.json"
            sed "s|$HOME|@HOME_DIR@|g" "$plugins_dir/known_marketplaces.json" \
              | jq . > "$plugins_config/known_marketplaces.json"
            echo "    known_marketplaces.json"
          end

          if test -f "$plugins_dir/blocklist.json"
            cp "$plugins_dir/blocklist.json" "$plugins_config/blocklist.json"
            echo "    blocklist.json"
          end

          # Plugin cache not tracked -- Claude Code auto-downloads from installed_plugins.json
        end

        # Format captured shell scripts to match CI shfmt flags so the
        # next auto-format pass is a no-op.
        set -l sh_files (${pkgs.findutils}/bin/find "$config_dir" -type f -name '*.sh')
        if test (count $sh_files) -gt 0
          ${pkgs.shfmt}/bin/shfmt -w -i 2 -ci $sh_files >/dev/null
        end

        if test $sync_status -ne 0
          return $sync_status
        end

        echo ""
        echo "Done. Review changes with: git diff $config_dir"
      '';
    };

    # Resolve a capture-sync conflict by picking which side wins.
    # Usage:  capture-resolve <relpath> --home|--repo
    # The relpath is the key the capture-sync output / state file uses,
    # e.g. "skills/gsuite-edit/SKILL.md" or "agents/foo.md".
    capture-resolve = {
      description = "Resolve a capture-sync conflict by picking which side wins";
      body = ''
        if test (count $argv) -lt 2
          echo "usage: capture-resolve <relpath> --home|--repo"
          return 2
        end

        set -l relpath $argv[1]
        set -l side $argv[2]
        set -l config_dir "${globals.paths.nixerator}/modules/apps/cli/claude-code/config"
        set -l claude_dir "$HOME/.claude"
        set -l state_file "$config_dir/.capture-state.json"
        set -l home_path "$claude_dir/$relpath"
        set -l repo_path "$config_dir/$relpath"

        switch $side
          case --home
            if not test -e "$home_path"
              echo "capture-resolve: $home_path does not exist"
              return 1
            end
            mkdir -p (dirname "$repo_path")
            cp "$home_path" "$repo_path"
            set -l new_hash (${pkgs.coreutils}/bin/sha256sum "$repo_path" | string split -f1 ' ')
            ${pkgs.jq}/bin/jq --arg key "$relpath" --arg h "$new_hash" \
              '.files[$key] = $h' "$state_file" > "$state_file.tmp"
            mv "$state_file.tmp" "$state_file"
            echo "Resolved $relpath using home; snapshot updated."
          case --repo
            if not test -e "$repo_path"
              echo "capture-resolve: $repo_path does not exist"
              return 1
            end
            mkdir -p (dirname "$home_path")
            cp "$repo_path" "$home_path"
            set -l new_hash (${pkgs.coreutils}/bin/sha256sum "$repo_path" | string split -f1 ' ')
            ${pkgs.jq}/bin/jq --arg key "$relpath" --arg h "$new_hash" \
              '.files[$key] = $h' "$state_file" > "$state_file.tmp"
            mv "$state_file.tmp" "$state_file"
            echo "Resolved $relpath using repo; snapshot updated."
          case '*'
            echo "usage: capture-resolve <relpath> --home|--repo"
            return 2
        end
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
