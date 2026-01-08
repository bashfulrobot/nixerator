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
