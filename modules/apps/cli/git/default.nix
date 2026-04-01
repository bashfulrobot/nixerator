{
  globals,
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.git;

  # gcom — Git Commit Workflow Tool
  # Two-phase git workflow:
  #   gcom start [-w] [branch-name]  — create branch or worktree
  #   gcom finish [--squash]         — auto-commit, merge to main, cleanup
  gcom = pkgs.writeShellApplication {
    name = "gcom";

    runtimeInputs = with pkgs; [
      git
      git-crypt
      fzf
      coreutils
      gnused
      findutils
    ];

    text = builtins.readFile ./gcom.sh;
  };
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

    # Enable gcmt conventional commit tool alongside git
    apps.cli.gcmt.enable = true;

    # System-level packages
    environment.systemPackages = with pkgs; [
      gcom
      git
      git-crypt
      git-filter-repo
    ];

    # Home Manager user configuration
    home-manager.users.${globals.user.name} = {

      programs = {
        fish = {
          shellAliases = {
            # core
            g = "git";
            ga = "git add";
            gaa = "git add -A";
            gc = "git commit";
            gcm = "git commit -m";
            gp = "git push";
            gpf = "git push --force-with-lease";
            gpl = "git pull";
            gf = "git fetch";
            gd = "git diff";
            gds = "git diff --staged";
            gs = "git status";
            # branching
            gb = "git branch";
            gco = "git checkout";
            gsw = "git switch";
            gm = "git merge";
            # log
            glog = "git log --oneline --graph --decorate";
            glast = "git log -1 HEAD";
            # stash
            gsta = "git stash";
            gstp = "git stash pop";
            gstl = "git stash list";
            # rebase
            grb = "git rebase";
            grbc = "git rebase --continue";
            grba = "git rebase --abort";
            # misc
            gcp = "git cherry-pick";
            gcl = "git clone";
            gwip = "git commit -am 'WIP'";
            gundo = "git reset --soft HEAD~1";
            # tools
            lg = "lazygit";
          };
        };

        git = {
          enable = true;
          settings = {
            user = {
              inherit (globals.user) email;
              name = globals.user.fullName;
              signingkey = "~/.ssh/id_ed25519.pub";
            };
            init.defaultBranch = "main";
            pull.rebase = true;
            push.default = "simple";
            merge.ff = "only";
            rebase.autoStash = true;
            rebase.updateRefs = true;
            branch.autoSetupRebase = "always";
            branch.sort = "-committerdate";
            rerere.enabled = true;
            fetch.prune = true;
            push.autoSetupRemote = true;
            push.followTags = true;
            diff.algorithm = "histogram";
            core.excludesFile = "~/.config/git/ignore";

            # SSH signing configuration
            commit.gpgsign = true;
            tag.gpgsign = true;
            gpg.format = "ssh";
            gpg.ssh.allowedSignersFile = "~/.config/git/allowed_signers";

            # Git aliases (for use as `git <alias>`)
            alias = {
              a = "add";
              aa = "add -A";
              c = "commit";
              cm = "commit -m";
              co = "checkout";
              sw = "switch";
              st = "status";
              br = "branch";
              df = "diff";
              dfs = "diff --staged";
              lg = "log --oneline --graph --decorate";
              ll = "log --oneline -n 20";
              last = "log -1 HEAD";
              unstage = "reset HEAD --";
              amend = "commit --amend --no-edit";
              undo = "reset --soft HEAD~1";
              wip = "commit -am 'WIP'";
              ss = "stash";
              sp = "stash pop";
              sl = "stash list";
              cp = "cherry-pick";
              rb = "rebase";
              rbc = "rebase --continue";
              rba = "rebase --abort";
              pf = "push --force-with-lease";
            };
          };
        };

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
              prs = "pr list";
              mine = "pr list --author @me";
              rv = "pr review";
              run = "run list";
              rw = "run watch";
            };
          };
        };
      };

      # Create allowed_signers file for SSH signing
      home.file.".config/git/allowed_signers".text = ''
        ${globals.user.email} ${globals.git.gitPubSigningKey}
      '';

      home.file.".config/git/ignore".text = ''
        .direnv/
        .DS_Store
        *.swp
        .helix/
        result
        result-*
      '';

    };

  };
}
