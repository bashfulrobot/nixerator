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
