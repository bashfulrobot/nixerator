{ pkgs, lib, username, globals, ... }:

{
  # Home Manager configuration
  home = {
    # Home Manager needs a bit of information about you and the
    # paths it should manage (from globals)
    inherit username;
    inherit (globals.user) homeDirectory;

    # This value determines the Home Manager release that your
    # configuration is compatible with (from globals)
    inherit (globals.defaults) stateVersion;

    # User packages
    packages = with pkgs; [
      # Add your packages here
      htop
      tree
      ripgrep
      fd
      bat
    ];

    # Home Manager environment variables (from globals)
    sessionVariables = {
      EDITOR = lib.mkForce (lib.getExe pkgs.${globals.preferences.editor});
    };

  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Override hypridle to disable suspend (lock + DPMS only for qbert)
  services.hypridle = {
    settings = {
      # Keep the general settings from hyprflake
      general = {
        ignore_dbus_inhibit = false;
        lock_cmd = "pidof hyprlock || hyprlock";
        unlock_cmd = "pkill --signal SIGUSR1 hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      # Override listeners: lock + DPMS only, no suspend
      listener = [
        # Lock screen after 5 minutes of inactivity
        {
          timeout = 300;
          on-timeout = "loginctl lock-session";
        }

        # Turn off display after 6 minutes of inactivity
        {
          timeout = 360;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }

        # Suspend listener removed for qbert - system will stay locked with display off
      ];
    };
  };

  # Git configuration is now handled by modules/cli/git

  # Bash configuration
  programs.bash = {
    enable = true;
    enableCompletion = true;
    bashrcExtra = ''
      # Add your custom bash configuration here
    '';
  };
}
