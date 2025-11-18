{ config, pkgs, lib, inputs, hostname, username, globals, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage (from globals)
  home.username = username;
  home.homeDirectory = globals.user.homeDirectory;

  # This value determines the Home Manager release that your
  # configuration is compatible with (from globals)
  home.stateVersion = globals.defaults.stateVersion;

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # User packages
  home.packages = with pkgs; [
    # Add your packages here
    htop
    tree
    ripgrep
    fd
    bat
  ];

  # Git configuration is now handled by modules/cli/git

  # Bash configuration
  programs.bash = {
    enable = true;
    enableCompletion = true;
    bashrcExtra = ''
      # Add your custom bash configuration here
    '';
  };

  # Home Manager environment variables (from globals)
  home.sessionVariables = {
    EDITOR = lib.getExe pkgs.${globals.preferences.editor};
  };
}
