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
    ];

    # Home Manager user configuration
    home-manager.users.${username} = {

      programs.git = {
        enable = true;
        settings = {
          user.name = globals.user.fullName;
          user.email = globals.user.email;
          init.defaultBranch = "main";
          pull.rebase = false;
          push.default = "simple";
          merge.ff = "only";

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
      programs.difftastic = {
        enable = true;
        git.enable = true;
        options = {
          background = "dark";
          color = "always";
        };
      };

      programs.lazygit = {
        enable = true;
        settings = {
          git.parseEmoji = true;
          gui.theme = {
            lightTheme = false;
            nerdFontVersion = "3";
          };
        };
      };

      programs.gh = {
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

  };
}
