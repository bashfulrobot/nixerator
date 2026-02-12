{
  globals,
  lib,
  pkgs,
  config,
  ...
}:

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
            gwork = {
              argumentNames = [ "name" ];
              body = ''
                git rev-parse --git-dir >/dev/null 2>&1
                if test $status -ne 0
                  echo "not inside a git repository"
                  return 1
                end

                if test -z "$name"
                  if type -q fzf
                    set -l existing (git branch --format='%(refname:short)' | grep '^work/' | fzf --prompt="branch> ")
                    if test -n "$existing"
                      git switch "$existing"
                      return $status
                    end
                  end

                  read -P "Branch name: " name
                  if test -z "$name"
                    echo "usage: gwork <branch-name>"
                    return 1
                  end
                end

                set -l git_status (git status --porcelain)
                if test -n "$git_status"
                  echo "working tree is not clean"
                  return 1
                end

                if not string match -q "*/*" "$name"
                  set name "work/$name"
                end

                git show-ref --verify --quiet "refs/heads/$name"
                if test $status -eq 0
                  echo "branch already exists: $name"
                  return 1
                end

                git switch main >/dev/null 2>&1
                git pull --ff-only >/dev/null 2>&1
                git switch -c "$name"
              '';
            };
            gfin = {
              body = ''
                git rev-parse --git-dir >/dev/null 2>&1
                if test $status -ne 0
                  echo "not inside a git repository"
                  return 1
                end

                set -l branch (git rev-parse --abbrev-ref HEAD)

                if test "$branch" = "main"
                  if type -q fzf
                    set -l pick (git branch --format='%(refname:short)' | grep '^work/' | fzf --prompt="finish branch> ")
                    if test -n "$pick"
                      set branch "$pick"
                    else
                      echo "no branch selected"
                      return 1
                    end
                  else
                    echo "already on main; nothing to finish"
                    return 1
                  end
                end

                set -l git_status (git status --porcelain)
                if test -n "$git_status"
                  echo "working tree is not clean"
                  return 1
                end

                git remote get-url origin >/dev/null 2>&1
                if test $status -ne 0
                  echo "remote 'origin' not configured"
                  return 1
                end

                git fetch origin --prune

                set -l main_sync (git rev-list --left-right --count origin/main...main)
                set -l behind (echo "$main_sync" | awk '{print $1}')
                set -l ahead (echo "$main_sync" | awk '{print $2}')
                if test "$behind" -gt 0
                  echo "main is behind origin/main"
                  echo "fix: git pull --ff-only"
                  return 1
                end
                if test "$ahead" -gt 0
                  echo "main is ahead of origin/main"
                  echo "fix: git push origin main"
                  return 1
                end

                git switch main
                git merge --ff-only "$branch"
                git push origin main
                git push origin --delete "$branch" 2>/dev/null; or true
                git branch -d "$branch"
              '';
            };
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
