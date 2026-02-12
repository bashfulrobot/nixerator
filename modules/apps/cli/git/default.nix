{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.cli.git;
  username = globals.user.name;
in
{
  options = {
    apps.cli.git.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable git and related tools.";
    };
  };

  config = lib.mkIf cfg.enable {

    # System-level packages
    environment.systemPackages = with pkgs; [
      git
      git-crypt
      git-filter-repo
    ];

    # Home Manager user configuration
    home-manager.users.${username} = {

      programs = {
        fish = {
          shellAliases = {
            g = "git";
            ga = "git add";
            gc = "git commit";
            gco = "git checkout";
            gst = "git status";
            gp = "git push";
            gpl = "git pull";
            gd = "git diff";
            gl = "git log";
            lg = "lazygit";
          };
          functions = {
            gwork = ''
              function gwork --argument-names name
                if test -z "$name"
                  if type -q fzf
                    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
                    if test -n "$repo_root"
                      set -l repo_name (basename "$repo_root")
                      set -l worktrees_dir "$HOME/dev/worktrees/$repo_name"
                      if test -d "$worktrees_dir"
                        set -l existing (git worktree list --porcelain | awk '
                          $1 == "worktree" { path = $2 }
                          $1 == "branch" { branch = $2 }
                          $1 == "branch" { print path "\t" branch }
                        ' | fzf --prompt="worktree> " --with-nth=1 --delimiter="\t")
                        if test -n "$existing"
                          set -l selected (echo "$existing" | awk -F'\t' '{print $1}')
                          if test -n "$selected"
                            cd "$selected"
                            return 0
                          end
                        end
                      end
                    end
                  end

                  read -P "Branch name: " name
                  if test -z "$name"
                    echo "usage: gwork <branch-name>"
                    return 1
                  end
                end

                git rev-parse --git-dir >/dev/null 2>&1
                if test $status -ne 0
                  echo "not inside a git repository"
                  return 1
                end

                set -l status (git status --porcelain)
                if test -n "$status"
                  echo "working tree is not clean"
                  return 1
                end

                if not string match -q "*/*" "$name"
                  set -l name "work/$name"
                end

                set -l repo_root (git rev-parse --show-toplevel)
                set -l repo_name (basename "$repo_root")
                set -l worktrees_dir "$HOME/dev/worktrees/$repo_name"
                set -l worktree_path "$worktrees_dir/$name"

                if test -e "$worktree_path"
                  echo "worktree path already exists: $worktree_path"
                  return 1
                end

                git show-ref --verify --quiet "refs/heads/$name"
                if test $status -eq 0
                  echo "branch already exists: $name"
                  return 1
                end

                git show-ref --verify --quiet "refs/remotes/origin/$name"
                if test $status -eq 0
                  echo "remote branch already exists: origin/$name"
                  return 1
                end

                mkdir -p "$worktrees_dir"
                git switch main
                git pull --ff-only
                git worktree add -b "$name" "$worktree_path" main
                cd "$worktree_path"
              end
            '';
            gfin = ''
              function gfin
                git rev-parse --git-dir >/dev/null 2>&1
                if test $status -ne 0
                  if type -q fzf
                    set -l existing (git worktree list --porcelain | awk '
                      $1 == "worktree" { path = $2 }
                      $1 == "branch" { branch = $2 }
                      $1 == "branch" { print path "\t" branch }
                    ' | fzf --prompt="worktree> " --with-nth=1 --delimiter="\t")
                    if test -n "$existing"
                      set -l selected (echo "$existing" | awk -F'\t' '{print $1}')
                      if test -n "$selected"
                        cd "$selected"
                      end
                    end
                  end

                  git rev-parse --git-dir >/dev/null 2>&1
                  if test $status -ne 0
                    echo "not inside a git repository"
                    return 1
                  end
                end

                set -l branch (git rev-parse --abbrev-ref HEAD)
                if test "$branch" = "main"
                  echo "already on main; refusing to finish"
                  return 1
                end

                set -l status (git status --porcelain)
                if test -n "$status"
                  echo "working tree is not clean"
                  return 1
                end

                set -l worktree_path (git rev-parse --show-toplevel)
                set -l main_path (git worktree list --porcelain | awk '
                  $1 == "worktree" { path = $2 }
                  $1 == "branch" && $2 == "refs/heads/main" { print path; exit }
                ')

                if test -z "$main_path"
                  echo "could not find main worktree"
                  return 1
                end

                git -C "$main_path" remote get-url origin >/dev/null 2>&1
                if test $status -ne 0
                  echo "remote 'origin' not configured"
                  return 1
                end

                git show-ref --verify --quiet "refs/heads/$branch"
                if test $status -ne 0
                  echo "branch does not exist: $branch"
                  return 1
                end

                git -C "$main_path" fetch origin --prune

                set -l main_sync (git -C "$main_path" rev-list --left-right --count origin/main...main)
                set -l behind (echo "$main_sync" | awk '{print $1}')
                set -l ahead (echo "$main_sync" | awk '{print $2}')
                if test "$behind" -gt 0
                  echo "main is behind origin/main"
                  echo "fix: git -C \"$main_path\" pull --ff-only"
                  return 1
                end
                if test "$ahead" -gt 0
                  echo "main is ahead of origin/main"
                  echo "fix: git -C \"$main_path\" push origin main"
                  return 1
                end

                git -C "$main_path" switch main
                git -C "$main_path" pull --ff-only
                git -C "$main_path" merge --ff-only "$branch"
                git -C "$main_path" push origin main
                git -C "$main_path" push origin --delete "$branch"
                git worktree remove "$worktree_path"
                git -C "$main_path" branch -d "$branch"
                cd "$HOME/dev"
              end
            '';
          };
        };
      };

      programs = {
        git = {
          enable = true;
          settings = {
            user = {
              inherit (globals.user) email;
              name = globals.user.fullName;
              signingkey = "~/.ssh/id_ed25519.pub";
            };
            init.defaultBranch = "main";
            pull.rebase = false;
            push.default = "simple";
            merge.ff = "only";

            # SSH signing configuration
            commit.gpgsign = true;
            tag.gpgsign = true;
            gpg.format = "ssh";
            gpg.ssh.allowedSignersFile = "~/.config/git/allowed_signers";

            # Git aliases
            alias = {
              a = "add";
              c = "commit";
              co = "checkout";
              st = "status";
              br = "branch";
            };
          };
        };

        # Difftastic is now a separate program
        difftastic = {
          enable = true;
          git.enable = true;
          options = {
            background = "dark";
            color = "always";
          };
        };

        lazygit = {
          enable = true;
          settings = {
            git.parseEmoji = true;
            gui.theme = {
              lightTheme = false;
              nerdFontVersion = "3";
            };
          };
        };

        gh = {
          enable = true;
          gitCredentialHelper.enable = true;
          settings = {
            editor = lib.getExe pkgs.${globals.preferences.editor};
            git_protocol = "ssh";
            prompt = "enabled";
            aliases = {
              co = "pr checkout";
              pv = "pr view";
            };
          };
        };
      };

      # Create allowed_signers file for SSH signing
      home.file.".config/git/allowed_signers".text = ''
        ${globals.user.email} ${globals.git.gitPubSigningKey}
      '';

    };

  };
}
