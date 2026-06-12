{
  pkgs,
  lib,
  globals,
  ...
}:

{
  # Home Manager configuration
  home = {
    # Home Manager needs a bit of information about you and the
    # paths it should manage (from globals)
    username = globals.user.name;
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

  # Hypridle configuration is now managed via hyprflake options
  # See hosts/qbert/power-management.nix for qbert-specific idle/suspend configuration

  # Git configuration is now handled by modules/cli/git

  # Bash configuration
  programs.bash = {
    enable = true;
    enableCompletion = true;
    bashrcExtra = ''
      # Add your custom bash configuration here
    '';
  };

  # Declared through hyprflake.hyprland.extraLua so it loads last and this
  # DP-3 rule wins over hyprflake's default wildcard monitor rule. Monitors
  # are configured declaratively here (not via DMS's Display Profiles GUI,
  # whose "Setup" button can't write hyprflake's read-only hyprland.lua).
  # vrr = 2 is "fullscreen only" (smooth VRR in fullscreen games, steady
  # 144Hz on the desktop — best fit for the G34WQC VA panel).
  hyprflake.hyprland.extraLua."monitor" = ''
    hl.monitor({
      output = "DP-3",
      mode = "3440x1440@144",
      position = "auto",
      scale = "1",
      vrr = 2,
    })
  '';
}
