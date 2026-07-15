{
  globals,
  inputs,
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.git;

  # Forgejo (git.srvrs.co) account the `tea` CLI logs in as. Token auth is what
  # actually authenticates; this field is informational for tea's own display.
  forgejoUser = "bashfulrobot";

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

  # Build-time-generated .gitattributes covering every language mergiraf
  # currently supports. Stays in sync with the installed mergiraf version.
  mergirafAttributes = pkgs.runCommand "mergiraf-gitattributes" { } ''
    ${pkgs.mergiraf}/bin/mergiraf languages --gitattributes > $out
  '';
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
      mergiraf
      # tea — Forgejo/Gitea official CLI, the gh-equivalent for git.srvrs.co.
      # Login config is rendered per-user by the activation script below.
      tea
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
            push = {
              default = "simple";
              autoSetupRemote = true;
              followTags = true;
            };
            merge = {
              ff = "only";
              conflictStyle = "diff3";

              # mergiraf — syntax-aware merge driver. Triggered per-file by
              # ~/.config/git/attributes (managed below).
              mergiraf = {
                name = "mergiraf";
                driver = "mergiraf merge --git %O %A %B -s %S -x %X -y %Y -p %P -l %L";
              };
            };
            rebase = {
              autoStash = true;
              updateRefs = true;
            };
            branch = {
              autoSetupRebase = "always";
              sort = "-committerdate";
            };
            rerere.enabled = true;
            fetch.prune = true;
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

      home.file = {
        # Create allowed_signers file for SSH signing
        ".config/git/allowed_signers".text = ''
          ${globals.user.email} ${globals.git.gitPubSigningKey}
        '';

        ".config/git/ignore".text = ''
          .direnv/
          .DS_Store
          *.swp
          .helix/
          result
          result-*
        '';

        # Wire every mergiraf-supported file extension to the merge driver.
        ".config/git/attributes".source = mergirafAttributes;
      };

      # Render the `tea` (Forgejo) login config from the runtime-rendered
      # secrets blob. Two reasons this is an activation script and not a
      # `home.file` or `tea login add`:
      #   1. Reading the token from ~/.config/nixos-secrets/secrets.json at
      #      switch time keeps it out of the Nix store (same intent as the
      #      GRAFANA_TOKEN/OP token render in the fish module).
      #   2. `tea login add` contacts git.srvrs.co to validate the token, which
      #      would fail the rebuild whenever that LAN host is unreachable. We
      #      hand-write the (verified) config schema instead — zero network.
      # Idempotent: re-rendered every activation, so a rotated token propagates.
      # Non-fatal if the secrets file or token is absent — tea stays unconfigured
      # and the REST/env path (FORGEJO_TOKEN) still works.
      home.activation.forgejoTeaLogin = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _secrets="$HOME/.config/nixos-secrets/secrets.json"
        _teacfg="$HOME/.config/tea/config.yml"
        if [ -f "$_secrets" ]; then
          _tok="$(${pkgs.jq}/bin/jq -r '.forgejo.apiToken // empty' "$_secrets")"
          if [ -n "$_tok" ]; then
            _cfg="$(printf 'logins:\n- name: srvrs\n  url: https://git.srvrs.co\n  token: %s\n  default: true\n  ssh_host: git.srvrs.co\n  insecure: false\n  user: %s\n' "$_tok" "${forgejoUser}")"
            $DRY_RUN_CMD install -Dm600 /dev/stdin "$_teacfg" <<<"$_cfg"
          fi
        fi
      '';

    };

  };
}
