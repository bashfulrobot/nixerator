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

  # forge — provider-aware git-forge helper. One CLI that dispatches to GitHub
  # (via gh) or the self-hosted Forgejo (via its Gitea-compatible REST API +
  # $FORGEJO_TOKEN) based on the repo's origin remote. Skills call `forge <verb>`
  # instead of `gh` directly, so the gh-vs-Forgejo split lives in one file.
  forge = pkgs.writeShellApplication {
    name = "forge";

    runtimeInputs = with pkgs; [
      git
      gh
      jq
      curl
      coreutils # base64
      gnused
    ];

    text = builtins.readFile ./forge.sh;
  };

  # Build-time-generated .gitattributes covering every language mergiraf
  # currently supports. Stays in sync with the installed mergiraf version.
  mergirafAttributes = pkgs.runCommand "mergiraf-gitattributes" { } ''
    ${pkgs.mergiraf}/bin/mergiraf languages --gitattributes > $out
  '';
in
{
  options = {
    apps.cli.git.enable = lib.mkEnableOption "git and related tools";
  };

  config = lib.mkIf cfg.enable {

    # Enable gcmt conventional commit tool alongside git
    apps.cli.gcmt.enable = true;

    # System-level packages
    environment.systemPackages = with pkgs; [
      gcom
      forge
      git
      git-crypt
      git-filter-repo
      mergiraf
      # tea — Forgejo/Gitea official CLI, the gh-equivalent for git.srvrs.co.
      # Login config (~/.config/tea/config.yml) is written by render-secrets from
      # the rendered .forgejo.apiToken, so a rotated token propagates on the next
      # `just render-secrets` rather than waiting for a generation-changing rebuild.
      # `render-secrets --push` only copies secrets.json to a peer, not the tea
      # config, so a pushed-to host regenerates its own config on its next local
      # `render-secrets`.
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
            # `gh dash`, not the bare `gh-dash` binary: the extension form is
            # the one that also works on the Mac (bashfulrobot/donkeykong),
            # where gh-dash has no Homebrew formula and is installed with
            # `gh extension install`. Here programs.gh-dash gives both.
            ghd = "gh dash";
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

            # difftastic as the git difftool default (mkForce: programs.kitty
            # also sets this via mkDefault, and kitty's `kitten diff` needs
            # kitty's terminal graphics protocol -- Rio, the terminal actually
            # in use, doesn't render it). Plain `git diff` is untouched
            # (diff.external is not set), so scripts/git-apply keep working.
            diff.tool = lib.mkForce "difftastic";
            difftool.difftastic.cmd = ''${lib.getExe pkgs.difftastic} --background=dark --color=always "$LOCAL" "$REMOTE"'';

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
              gdt = "difftool -y -t difftastic";
              gdts = "difftool -y -t difftastic --staged";
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
          # git.enable stays off: its "difftool" mode sets diff.tool via
          # mkDefault, same priority as programs.kitty's own mkDefault "kitty"
          # -- a real conflicting-definition eval error, not a preference tie.
          # difftool.difftastic.cmd is wired by hand below, and diff.tool is
          # forced to difftastic (kitty's `kitten diff` needs kitty's terminal
          # graphics protocol, which Rio -- the terminal actually in use --
          # doesn't render).
          git.enable = false;
          options = {
            background = "dark";
            color = "always";
          };
        };

        # Only settings that DEPART from a lazygit default. `lazygit --config`
        # prints the full default set and
        # https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md
        # documents every key. The Mac (bashfulrobot/donkeykong) deploys the
        # same two keys with chezmoi -- at
        # ~/Library/Application Support/lazygit/config.yml, because lazygit only
        # honours the XDG path on macOS when XDG_CONFIG_HOME is set and that
        # machine does not set it. Different path, same settings.
        #
        # 2026-09: dropped `gui.theme.lightTheme = false` and corrected
        # `gui.theme.nerdFontVersion` to `gui.nerdFontsVersion`. Neither old key
        # exists in lazygit's schema -- lightTheme was removed upstream, and the
        # font key is plural and sits directly under `gui`, not under `theme`.
        # lazygit unmarshals its config non-strictly, so both were silently
        # ignored rather than failing: the icons had been rendering as v2
        # codepoints this whole time.
        lazygit = {
          enable = true;
          settings = {
            # Render :emoji: shortcodes in commit messages as emoji. gcmt writes
            # conventional commits with them, so the log reads as intended
            # rather than as literal colon-wrapped names.
            git.parseEmoji = true;
            # The Nerd Font glyph set to draw from. Empty (the default) shows no
            # icons at all; "2" gives codepoints that moved in v3 and render as
            # tofu against the v3 font the terminal actually uses.
            gui.nerdFontsVersion = "3";
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

        # Terminal dashboard for PRs, issues and notifications
        # (https://www.gh-dash.dev). The home-manager module installs the
        # package AND registers it in programs.gh.extensions above, so both
        # `gh dash` and the bare `gh-dash` binary work.
        #
        # Only settings that DEPART from a default live here. gh-dash's own
        # defaults already give the three sections worth having -- "My Pull
        # Requests", "Needs My Review", "Involved" (is:open author:@me,
        # review-requested:@me, involves:@me -author:@me) -- and restating them
        # would pin values this repo never meant to choose. The full schema is
        # at https://gh-dash.dev/schema.json.
        #
        # The Mac (bashfulrobot/donkeykong) deploys the same settings to the
        # same ~/.config/gh-dash/config.yml path with chezmoi; gh-dash resolves
        # that path identically on Linux and macOS. Change one, change the other.
        gh-dash = {
          enable = true;
          settings = {
            # Lets `gh dash` open a PR's checkout locally instead of only in a
            # browser. Every repo is cloned to ~/git/<name> on both machines
            # (globals.paths.nixerator is ~/git/nixerator, and the Mac's README
            # clones to ~/git/donkeykong), so one wildcard covers them all. The
            # schema requires the value to carry the asterisk when the key does.
            #
            # Literal "~", not globals.user.homeDirectory: gh-dash expands it,
            # and it keeps this byte-identical to the Mac's chezmoi copy.
            repoPaths = {
              "bashfulrobot/*" = "~/git/*";
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

    };

  };
}
