{
  globals,
  lib,
  config,
  ...
}:

let
  cfg = config.apps.cli.fish;
in
{
  options = {
    apps.cli.fish.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable fish shell via home-manager.";
    };
  };

  config = lib.mkIf cfg.enable {

    # Enable fish at system level (required for user shell)
    programs.fish.enable = true;

    # Home Manager user configuration
    home-manager.users.${globals.user.name} = {

      programs.fish = {
        enable = true;

        # Fish shell configuration
        shellInit = ''
          # Disable greeting
          set fish_greeting
        '';

        # Shell aliases (for programmatic/script-facing use)
        shellAliases = {
          glow = "glow -p";
          mdr = "glow -p";
          ni = "nix run 'nixpkgs#nix-index' --extra-experimental-features 'nix-command flakes'";
          nix-info = "nix-info --markdown --sandbox --host-os";
          bt-toggle = "rfkill toggle bluetooth; rfkill list bluetooth | grep -q 'Soft blocked: yes'; and echo 'Bluetooth: OFF'; or echo 'Bluetooth: ON'";
        };

        # Abbreviations expand in-place (visible before execution, editable)
        shellAbbrs = {
          gs = "git status";
          gon = "cd ${globals.paths.nixerator}";
          goh = "cd ${globals.paths.hyprflake}";
          upgrade = "cd ${globals.paths.nixerator} && just upgrade";
          rebuild = "cd ${globals.paths.nixerator} && just rebuild";
        };

        # Custom functions
        functions = {
          kcfg = ''
            set -l clusters_dir "$HOME/.kube/clusters"
            set -l active_config "$HOME/.kube/config"

            if not test -d "$clusters_dir"
              echo "Error: $clusters_dir directory does not exist"
              return 1
            end

            set -l selected (find "$clusters_dir" -type f | fzf --prompt="Select kubeconfig: " --height=40% --border)

            if test -n "$selected"
              cp "$selected" "$active_config"
              echo "✓ Activated kubeconfig: $(basename $selected)"
            else
              echo "No selection made"
            end
          '';

          tcfg = ''
            set -l clusters_dir "$HOME/.talos/clusters"
            set -l active_config "$HOME/.talos/config"

            if not test -d "$clusters_dir"
              echo "Error: $clusters_dir directory does not exist"
              return 1
            end

            set -l selected (find "$clusters_dir" -type f | fzf --prompt="Select talosconfig: " --height=40% --border)

            if test -n "$selected"
              cp "$selected" "$active_config"
              echo "✓ Activated talosconfig: $(basename $selected)"
            else
              echo "No selection made"
            end
          '';

          copy = ''
            if test (count $argv) -gt 0
              if not test -f "$argv[1]"
                echo "Error: $argv[1] is not a file"
                return 1
              end
              wl-copy < "$argv[1]"
              echo "✓ Copied: $argv[1]"
            else
              set -l selected (fzf --prompt="Copy file: " --height=40% --border --preview="head -50 {}")
              if test -n "$selected"
                wl-copy < "$selected"
                echo "✓ Copied: $selected"
              else
                echo "No selection made"
              end
            end
          '';

          af = ''
            alias | fzf --prompt="Alias: " --height=40% --border
          '';

          ff = ''
            functions | fzf --prompt="Function: " --height=40% --border
          '';

          mkcd = ''
            mkdir -p $argv[1]; and cd $argv[1]
          '';

          kns = ''
            set -l namespace (kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | fzf --prompt="Select namespace: " --height=40% --border)

            if test -n "$namespace"
              kubectl config set-context --current --namespace="$namespace"
              echo "✓ Switched to namespace: $namespace"
            else
              echo "No selection made"
            end
          '';

          git-audit = {
            description = "Audit git branches, worktrees, and linked GitHub PRs/issues via gh";
            body = ''
              if not git rev-parse --git-dir >/dev/null 2>&1
                echo "Not a git repo"
                return 1
              end

              set -l now (date +%s)
              set -l stale_days 30
              set -l warn_days 14

              # require gh cli and a GitHub remote
              if not command -q gh
                echo "gh cli not found — install GitHub CLI for PR/issue integration"
                return 1
              end
              if not gh repo view >/dev/null 2>&1
                echo "Not a GitHub repo (no remote found)"
                return 1
              end

              set -l repo_url (gh repo view --json url --jq '.url' 2>/dev/null)

              # --- Batch-fetch all PRs (open + closed + merged) in one call ---
              set -l _pr_branches
              set -l _pr_states
              set -l _pr_numbers
              set -l _pr_urls
              set -l _pr_titles
              for pr_line in (gh pr list --state all --limit 200 --json headRefName,number,state,url,title --jq '.[] | "\(.headRefName)\t\(.state)\t\(.number)\t\(.url)\t\(.title)"' 2>/dev/null)
                set -l pr_parts (string split \t $pr_line)
                set -a _pr_branches $pr_parts[1]
                set -a _pr_states $pr_parts[2]
                set -a _pr_numbers $pr_parts[3]
                set -a _pr_urls $pr_parts[4]
                set -a _pr_titles $pr_parts[5]
              end

              # --- Batch-fetch all open issues in one call ---
              set -l _issue_numbers
              set -l _issue_states
              set -l _issue_titles
              set -l _issue_urls
              for issue_line in (gh issue list --state all --limit 200 --json number,state,title,url --jq '.[] | "\(.number)\t\(.state)\t\(.title)\t\(.url)"' 2>/dev/null)
                set -l issue_parts (string split \t $issue_line)
                set -a _issue_numbers $issue_parts[1]
                set -a _issue_states $issue_parts[2]
                set -a _issue_titles $issue_parts[3]
                set -a _issue_urls $issue_parts[4]
              end

              # --- Build linked-branches from PRs (gh api for branch→issue links) ---
              # Also check PR body/title for "closes #N", "fixes #N" patterns
              set -l _linked_pr_branches
              set -l _linked_issue_nums
              set -l _linked_issue_states
              for i in (seq (count $_pr_branches))
                # scan PR title for issue refs like #123
                for issue_ref in (string match -ra '#(\d+)' "$_pr_titles[$i]")
                  set -l inum (string replace '#' "" $issue_ref)
                  # verify it's a real issue in our cache
                  for j in (seq (count $_issue_numbers))
                    if test "$_issue_numbers[$j]" = "$inum"
                      set -a _linked_pr_branches $_pr_branches[$i]
                      set -a _linked_issue_nums $inum
                      set -a _linked_issue_states $_issue_states[$j]
                    end
                  end
                end
              end

              # helper: print PR info for a branch
              function __ga_pr --no-scope-shadowing -a branch_name
                for i in (seq (count $_pr_branches))
                  if test "$_pr_branches[$i]" = "$branch_name"
                    switch $_pr_states[$i]
                      case OPEN
                        set_color green
                        printf " PR #%s OPEN" "$_pr_numbers[$i]"
                      case MERGED
                        set_color magenta
                        printf " PR #%s MERGED" "$_pr_numbers[$i]"
                      case CLOSED
                        set_color red
                        printf " PR #%s CLOSED" "$_pr_numbers[$i]"
                    end
                    set_color normal
                    set_color --dim
                    printf " %s" "$_pr_urls[$i]"
                    set_color normal
                    return
                  end
                end
              end

              # helper: print linked issue info for a branch
              function __ga_issue --no-scope-shadowing -a branch_name
                for i in (seq (count $_linked_pr_branches))
                  if test "$_linked_pr_branches[$i]" = "$branch_name"
                    switch $_linked_issue_states[$i]
                      case OPEN
                        set_color green
                        printf " Issue #%s OPEN" "$_linked_issue_nums[$i]"
                      case CLOSED
                        set_color red
                        printf " Issue #%s CLOSED" "$_linked_issue_nums[$i]"
                    end
                    set_color normal
                    return
                  end
                end
              end

              # helper: print branch line with age colouring
              function __ga_branch_line --no-scope-shadowing -a prefix -a name -a age -a epoch -a subject -a name_width
                set -l age_secs (math $now - $epoch)
                set -l age_days (math "floor($age_secs / 86400)")

                if test $age_days -ge $stale_days
                  set_color red
                else if test $age_days -ge $warn_days
                  set_color yellow
                else
                  set_color normal
                end

                printf "%s %-"$name_width"s  %s" "$prefix" "$name" "$age"
                if test $age_days -ge $stale_days
                  set_color red
                  printf "  STALE"
                end
                __ga_pr "$name"
                __ga_issue "$name"
                set_color --dim
                printf "  %s\n" (string sub -l 50 "$subject")
                set_color normal
              end

              # --- Worktrees ---
              set -l wt_count 0
              set -l wt_entries (git worktree list --porcelain 2>/dev/null)
              if test -n "$wt_entries"
                set_color --bold cyan
                echo "╭─ Worktrees"
                set_color normal
                set -l wt_path ""
                for line in $wt_entries
                  if string match -q "worktree *" $line
                    set wt_path (string replace "worktree " "" $line)
                  else if string match -q "branch *" $line
                    set -l wt_branch (string replace "branch refs/heads/" "" $line)
                    set wt_count (math $wt_count + 1)
                    set_color yellow
                    printf "│  %s" "$wt_path"
                    set_color normal
                    printf "  (%s)" "$wt_branch"
                    __ga_pr "$wt_branch"
                    __ga_issue "$wt_branch"
                    echo ""
                  else if string match -q "HEAD *" $line
                    if test -n "$wt_path"
                      set wt_count (math $wt_count + 1)
                      set_color yellow
                      printf "│  %s" "$wt_path"
                      set_color normal
                      printf "  (detached)"
                      echo ""
                    end
                  end
                end
                set_color --bold cyan
                echo "╰─"
                set_color normal
                echo ""
              end

              # --- Local branches ---
              set_color --bold green
              echo "╭─ Local Branches"
              set_color normal

              set -l current_branch (git rev-parse --abbrev-ref HEAD 2>/dev/null)

              for branch in (git for-each-ref --sort=-committerdate --format='%(refname:short)|%(committerdate:relative)|%(committerdate:unix)|%(subject)' refs/heads/)
                set -l parts (string split "|" $branch)
                set -l name $parts[1]
                set -l age $parts[2]
                set -l epoch $parts[3]
                set -l subject $parts[4]

                if test "$name" = "$current_branch"
                  set -l prefix "│ ▸"
                else
                  set -l prefix "│  "
                end

                __ga_branch_line "$prefix" "$name" "$age" "$epoch" "$subject" 30
              end

              set_color --bold green
              echo "╰─"
              set_color normal
              echo ""

              # --- Remote branches (excluding HEAD) ---
              git fetch --prune --quiet 2>/dev/null

              set_color --bold magenta
              echo "╭─ Remote Branches"
              set_color normal

              for branch in (git for-each-ref --sort=-committerdate --format='%(refname:short)|%(committerdate:relative)|%(committerdate:unix)|%(subject)' refs/remotes/ | grep -v '/HEAD$')
                set -l parts (string split "|" $branch)
                set -l name $parts[1]
                set -l age $parts[2]
                set -l epoch $parts[3]
                set -l subject $parts[4]

                set -l local_name (string replace -r '^origin/' "" "$name")
                if git show-ref --verify --quiet "refs/heads/$local_name"
                  set -l track_icon "│ ↔"
                else
                  set -l track_icon "│  "
                end

                __ga_branch_line "$track_icon" "$name" "$age" "$epoch" "$subject" 35
              end

              set_color --bold magenta
              echo "╰─"
              set_color normal

              # --- Open PRs without local branch ---
              set -l orphan_prs
              for i in (seq (count $_pr_branches))
                if test "$_pr_states[$i]" = OPEN
                  if not git show-ref --verify --quiet "refs/heads/$_pr_branches[$i]"
                    set -a orphan_prs $i
                  end
                end
              end
              if test (count $orphan_prs) -gt 0
                echo ""
                set_color --bold yellow
                echo "╭─ Open PRs (no local branch)"
                set_color normal
                for i in $orphan_prs
                  set_color green
                  printf "│  PR #%-6s" "$_pr_numbers[$i]"
                  set_color normal
                  printf "%-30s" "$_pr_branches[$i]"
                  set_color --dim
                  printf "  %s\n" (string sub -l 50 "$_pr_titles[$i]")
                  set_color normal
                end
                set_color --bold yellow
                echo "╰─"
                set_color normal
              end

              # --- Summary ---
              echo ""
              set -l local_count (git for-each-ref --format='x' refs/heads/ | count)
              set -l remote_count (git for-each-ref --format='x' refs/remotes/ | count)
              set -l stale_local 0
              for epoch in (git for-each-ref --format='%(committerdate:unix)' refs/heads/)
                if test (math $now - $epoch) -ge (math "$stale_days * 86400")
                  set stale_local (math $stale_local + 1)
                end
              end
              set -l stale_remote 0
              for epoch in (git for-each-ref --format='%(committerdate:unix)' refs/remotes/)
                if test (math $now - $epoch) -ge (math "$stale_days * 86400")
                  set stale_remote (math $stale_remote + 1)
                end
              end
              set -l open_pr_count 0
              for state in $_pr_states
                if test "$state" = OPEN
                  set open_pr_count (math $open_pr_count + 1)
                end
              end

              set_color --bold
              printf "Summary: %d local (%d stale) · %d remote (%d stale) · %d worktrees · %d open PRs · %d+ days = stale\n" $local_count $stale_local $remote_count $stale_remote $wt_count $open_pr_count $stale_days
              set_color normal

              # cleanup
              functions -e __ga_pr
              functions -e __ga_issue
              functions -e __ga_branch_line
            '';
          };

          gsp = ''
            if not git rev-parse --git-dir >/dev/null 2>&1
              echo "Not a git repo"
              return 1
            end

            set -l current_branch (git rev-parse --abbrev-ref HEAD)

            git fetch origin

            set -l local_only (git log "origin/$current_branch..$current_branch" --oneline 2>/dev/null)
            set -l remote_only (git log "$current_branch..origin/$current_branch" --oneline 2>/dev/null)

            if test -n "$local_only" -a -n "$remote_only"
              echo "Diverged — local and remote both have commits:"
              echo ""
              echo "Local:"
              echo "$local_only"
              echo ""
              echo "Remote:"
              echo "$remote_only"
              echo ""
              echo "Resolve manually (rebase, merge, or force-push)."
              return 1

            else if test -n "$local_only"
              echo "Pushing unpushed commits..."
              git push origin "$current_branch"
              echo "Pushed to origin/$current_branch"

            else if test -n "$remote_only"
              echo "Aligning git state with remote..."
              git reset --hard "origin/$current_branch"
              git clean -fd
              echo "Git state aligned with origin/$current_branch"

            else
              echo "Already in sync with origin/$current_branch"
            end

            git status --short
          '';
        };
      };

    };

  };
}
