{ user-settings, config, lib, pkgs, ... }:

let
  cfg = config.apps.gui.one-password;
in {

  options = {
    apps.gui.one-password.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable 1Password password manager.";
    };
  };

  config = lib.mkIf cfg.enable {

    # The 1Password app can unlock your browser extension using a special native messaging process. This streamlines your 1Password experience: Once you unlock 1Password from your tray icon, your browser extensions will be unlocked as well.
    environment.etc = {
      "1password/custom_allowed_browsers" = {
        text = ''
          chromium
          zen
          zen-bin
        '';
        mode = "0755";
      };
    };

    # Enable 1Password CLI and GUI with polkit authorization
    programs = {
      _1password = {
        enable = true;
        package = pkgs._1password-cli;
      };
      _1password-gui = {
        enable = true;
        package = pkgs._1password-gui;
        polkitPolicyOwners = [ "${user-settings.user.username}" ];
      };
    };

    # used in Gnome and Hyprland
    home-manager.users."${user-settings.user.username}" = {
      home.file."1password.desktop" = {
        source = ./1password.desktop;
        target = ".config/autostart/1password.desktop";
      };

      # SSH configuration to use 1Password SSH agent
      # TODO: TEST this
      # programs.ssh = {
      #   enable = true;
      #   extraConfig = ''
      #     Host *
      #         IdentityAgent ~/.1password/agent.sock
      #   '';
      # };

    };
  };
}
