{
  globals,
  pkgs,
  statusLineScript,
}:

{
  functions = {
    # Bare `claude` in a folder -> start a NAMED background session and attach
    # to it, so every session I start is a citizen of the agent-view board
    # (visible across all projects, git or not). Anything with args -- claude
    # agents / -r / -p / mcp / --bg ... -- passes straight through unchanged.
    # Escape hatch: `command claude` runs a plain foreground session.
    #
    # --remote-control "$name" rides along with --bg under the same name, so
    # the session is also picked up by claude.ai/code and the iOS app without
    # a separate czj/zellij launch.
    claude = {
      wraps = "claude";
      body = ''
        if test (count $argv) -eq 0; and isatty stdin
            set -l default_name (basename $PWD)
            if not read -P "New background session -- name [$default_name] (Ctrl-D cancels): " name
                echo "Cancelled."
                return 0
            end
            test -z "$name"; and set name $default_name

            set -l out (command claude --bg --name "$name" --remote-control "$name")
            printf '%s\n' $out
            set -l id (string match -rg 'claude attach (\S+)' -- $out)
            if test -n "$id"
                command claude attach $id
            else
                echo "claude: could not parse session id; open it from 'claude agents'." >&2
                return 1
            end
            return
        end

        # Foreground / subcommand path: run as-is, then offer to clean up a
        # leftover project .mcp.json on exit.
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

        # settings.json -- canonicalize the live home copy back to repo form, then
        # hand it to capture-sync's snapshot-guarded 3-way (below) instead of
        # copying it over the repo unconditionally. The old unconditional copy was
        # racy: a pre-rebuild capture wrote a STALE home over a freshly-edited repo,
        # reverting any repo-only settings.json change before the rebuild ran.
        #
        # Canonicalization (must reproduce the repo source byte-for-byte when
        # nothing has diverged, so the 3-way hashes line up):
        #   - statusline store path      -> @STATUSLINE_COMMAND@ placeholder
        #   - extraKnownMarketplaces / enabledPlugins: owned by cfg/plugin-config.nix
        #     (merged at activation) -> dropped
        #   - permissions.ask:           Nix-owned (activation pins it) -> dropped
        #   - hooks with a /nix/store command: EVERY Nix-owned hook is injected at
        #     activation (cfg/activation.nix) with its store path, so its volatile
        #     hash must never be committed. Stripping any hook whose command lives
        #     under /nix/store is drift-proof: it covers every current and future
        #     injected hook automatically, and leaves the repo-authored inline
        #     `bash -c '...'` hooks (which carry no store path) untouched. This
        #     replaces a hand-maintained name alternation that silently rotted
        #     whenever a new injected hook was added (guard-secret-commands and
        #     scrub-secret-output leaked their store paths into the repo exactly
        #     that way).
        # After stripping, any event array left empty is dropped entirely.
        set -l settings_tmp ""
        if test -f "$claude_dir/settings.json"
          set settings_tmp (mktemp)
          sed "s|$statusline_pattern|@STATUSLINE_COMMAND@|g" "$claude_dir/settings.json" \
            | jq 'del(.extraKnownMarketplaces, .enabledPlugins, .permissions.ask)
                  | .hooks = ((.hooks // {})
                      | map_values(map(select((.hooks[0].command // "")
                          | test("/nix/store/") | not)))
                      | with_entries(select(.value | length > 0)))' > "$settings_tmp"
        end

        # 3-way sync of skills, agents, output-styles, top-level CLAUDE.md, and
        # settings.json (the last via --settings-home/--settings-repo, a
        # capture-only reconcile that never writes the derived home side).
        # capture-sync.py reads / writes $state_file (committed JSON) and
        # respects the same .capture-ignore files the old loop did.
        set -l sync_args \
          --state-file "$state_file" \
          --home-root "$claude_dir" \
          --repo-root "$config_dir" \
          --section all
        if test -n "$settings_tmp"
          set -a sync_args --settings-home "$settings_tmp" --settings-repo "$config_dir/settings.json"
        end

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
        # The generic section counts exclude the settings.json key -- it rides the
        # same summary but is reported on its own line below.
        if test -s "$sync_stdout"
          set noop_count (${pkgs.jq}/bin/jq '[.actions[] | select(.action=="noop" and .key!="settings.json")] | length' $sync_stdout 2>/dev/null)
          set capture_count (${pkgs.jq}/bin/jq '[.actions[] | select(.action=="capture" and .key!="settings.json")] | length' $sync_stdout 2>/dev/null)
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

        # settings.json rides the same summary but reports on its own line, since
        # it is a capture-only reconcile with distinct actions (seed / keep-repo).
        if test -n "$settings_tmp"; and test -s "$sync_stdout"
          set -l settings_action (${pkgs.jq}/bin/jq -r '.actions[] | select(.key=="settings.json") | .action' $sync_stdout 2>/dev/null)
          switch "$settings_action"
            case capture
              echo "  settings.json: captured (home -> repo)"
            case keep-repo
              echo "  settings.json: repo kept (PR/merge ahead of stale home)"
            case seed
              echo "  settings.json: baseline recorded"
            case conflict
              echo "  settings.json: CONFLICT (home and repo both diverged)"
            case '*'
              # noop / empty: in sync, stay quiet
          end
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
        test -n "$settings_tmp"; and rm -f $settings_tmp

        # Plugins -- known_marketplaces.json is no longer captured (marketplaces
        # are owned declaratively in cfg/plugin-config.nix). Only installed_plugins.json
        # (SHA-stamped install record) and blocklist.json are captured here.
        set -l plugins_dir "$claude_dir/plugins"
        set -l plugins_config "$config_dir/plugins"
        if test -f "$plugins_dir/installed_plugins.json"
          echo "  plugins:"
          mkdir -p "$plugins_config"

          sed "s|$HOME|@HOME_DIR@|g" "$plugins_dir/installed_plugins.json" \
            | jq . > "$plugins_config/installed_plugins.json"
          echo "    installed_plugins.json"

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
    #
    # The relpath is validated against path traversal (no '..' segments,
    # no leading '/') before being joined onto $claude_dir / $config_dir.
    # Without this guard, `capture-resolve ../../.ssh/id_ed25519 --home`
    # would copy the user's private key into the public repo.
    capture-resolve = {
      description = "Resolve a capture-sync conflict by picking which side wins";
      body = ''
        if test (count $argv) -lt 2
          echo "usage: capture-resolve <relpath> --home|--repo"
          return 2
        end

        set -l relpath $argv[1]
        set -l side $argv[2]

        # Reject absolute paths and any path containing a '..' segment.
        # `string match -qr` does regex matching: '(^|/)\.\.(/|$)' catches
        # '..' as a standalone component; '^/' catches absolute paths.
        if string match -qr '(^|/)\.\.(/|$)|^/' -- $relpath
          echo "capture-resolve: refusing relpath with '..' or leading '/' ($relpath)" >&2
          return 2
        end

        # settings.json is not resolvable this way: its home side is a DERIVED
        # file (activation injects store-path hooks + the plugin overlay), so
        # copying raw ~/.claude/settings.json into the repo would commit volatile
        # store paths. To take repo: just rebuild (activation redeploys repo ->
        # home). To take your live home edits: fold them into
        # config/settings.json by hand, then re-run the capture.
        if test "$relpath" = settings.json
          echo "capture-resolve: settings.json can't be resolved here (home is derived)." >&2
          echo "  Take repo: rebuild (activation redeploys it to home)." >&2
          echo "  Take home: hand-edit config/settings.json to match, then re-capture." >&2
          return 2
        end

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

    # ── Background-session ("agent view") helpers ──────────────────────
    # Background Claude sessions carry short job ids that don't tab-complete.
    # These wrap `claude agents --json` so you pick a session by name instead.

    # List every tracked session (interactive + background), readable.
    cls = {
      description = "List Claude sessions (id / state / name / cwd)";
      body = ''
        command claude agents --json --all \
          | ${pkgs.jq}/bin/jq -r '.[] | "\(.id // "-")\t\(.state // .status)\t\(.name // "(unnamed)")\t\(.cwd)"' \
          | ${pkgs.util-linux}/bin/column -t -s \t
      '';
    };

    # fzf-pick background session(s) and `claude rm` them. Only background
    # sessions (those with a job id) are removable; push or merge first --
    # a clean Claude-created worktree is removed along with the session.
    crm = {
      description = "Pick background Claude session(s) with fzf and remove them";
      body = ''
        set -l rows (command claude agents --json --all 2>/dev/null \
          | ${pkgs.jq}/bin/jq -r '.[] | select(.id) | "\(.id)\t\(.name // "(unnamed)")\t\(.state // .status)\t\(.cwd)"')
        if test -z "$rows"
          echo "No background sessions to remove."
          return 0
        end
        set -l picks (printf '%s\n' $rows \
          | ${pkgs.fzf}/bin/fzf --multi --delimiter=\t --with-nth=2.. \
              --header='TAB=multi-select  ENTER=claude rm  ESC=cancel  (push/merge first!)')
        if test -z "$picks"
          echo "Cancelled -- nothing removed."
          return 0
        end
        for line in $picks
          set -l id (string split \t -- $line)[1]
          echo "-> claude rm $id"
          command claude rm $id
        end
      '';
    };

    # Prune stale worktree admin entries and list Claude-created git
    # worktrees under ~/git and ~/dev so leftovers are easy to spot.
    cwt-sweep = {
      description = "Prune + list Claude-created git worktrees across repos";
      body = ''
        for wt in (${pkgs.findutils}/bin/find ~/git ~/dev -type d -path '*/.claude/worktrees' 2>/dev/null)
          set -l repo (dirname (dirname $wt))
          test -d $repo/.git; or continue
          echo "── $repo ──"
          git -C $repo worktree prune
          git -C $repo worktree list
        end
      '';
    };

    # fzf cheat sheet over installed Claude Code skills (~/.claude/skills),
    # read-only: fuzzy-search name/description, preview renders the full
    # SKILL.md via glow. ENTER and ESC both just quit -- nothing is invoked.
    skills = {
      description = "Fuzzy-search installed Claude Code skills, preview full SKILL.md";
      body = ''
        set -l dir ~/.claude/skills
        set -l rows
        for f in $dir/*/SKILL.md
          set -l meta (${pkgs.yq-go}/bin/yq --front-matter=extract -o=json '.' $f 2>/dev/null)
          test -z "$meta"; and continue
          set -l name (echo $meta | ${pkgs.jq}/bin/jq -r '.name // empty')
          set -l desc (echo $meta | ${pkgs.jq}/bin/jq -r '.description // empty' | string join ' ')
          test -z "$name"; and continue
          set -a rows $name\t$desc
        end
        if test -z "$rows"
          echo "No skills found in $dir"
          return 0
        end
        printf '%s\n' $rows | sort \
          | ${pkgs.fzf}/bin/fzf --delimiter=\t --with-nth=1,2 \
              --header='Claude Code skills  (type to filter, ENTER/ESC to quit)' \
              --preview="${pkgs.glow}/bin/glow $dir/{1}/SKILL.md" \
              --preview-window=right:60% \
          > /dev/null
      '';
    };

    # fzf-pick a common project folder and launch a NAMED background Claude
    # session in it -- the point is to skip the name prompt the bare `claude`
    # wrapper shows, since these dirs are opened all the time. Candidates:
    # every repo under ~/git plus ~/dev/kong and ~/dev/scratch themselves.
    # An optional arg pre-seeds the fzf query (`cj nixer` -> jumps straight in
    # when it's the only match). Session name = folder basename; the launch +
    # attach path mirrors the bare `claude` wrapper above.
    cj = {
      description = "fzf-pick a project folder and start a named background Claude session there";
      body = ''
        set -l dirs
        for d in $HOME/git/*
            test -d $d; and set -a dirs $d
        end
        for d in $HOME/dev/kong $HOME/dev/scratch
            test -d $d; and set -a dirs $d
        end
        if test -z "$dirs"
            echo "cj: no candidate folders found under ~/git or ~/dev." >&2
            return 1
        end

        set -l pick (printf '%s\n' $dirs \
          | ${pkgs.fzf}/bin/fzf --query="$argv" --select-1 \
              --header='Pick a folder -> background Claude session  (ENTER=go  ESC=cancel)')
        if test -z "$pick"
            echo "Cancelled."
            return 0
        end

        cd $pick; or return 1
        set -l name (basename $pick)

        set -l out (command claude --bg --name "$name" --remote-control "$name")
        printf '%s\n' $out
        set -l id (string match -rg 'claude attach (\S+)' -- $out)
        if test -n "$id"
            command claude attach $id
        else
            echo "claude: could not parse session id; open it from 'claude agents'." >&2
            return 1
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
