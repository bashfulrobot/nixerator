{ lib, pkgs, config, globals, username, ... }:

let
  cfg = config.suites.desktop;
in
{
  options = {
    suites.desktop.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable desktop environment suite with Hyprland via hyprflake.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Hyprflake Configuration
    # Centralized desktop environment configuration for all workstations
    # Individual hosts can override these settings in their configuration.nix
    hyprflake = {
      # Enable hyprflake Plymouth theme
      plymouth.enable = lib.mkDefault true;

      # Color scheme - Base16 theme name
      # Browse available schemes: https://tinted-theming.github.io/base16-gallery/
      colorScheme = lib.mkDefault "catppuccin-mocha";

      # Wallpaper - local file path
      # Default: Catppuccin Mocha galaxy-waves.jpg (included in hyprflake)
      # Override in host configuration with:
      # hyprflake.wallpaper = ./path/to/your-wallpaper.png;

      # Font configuration - using hyprflake defaults
      # Default monospace: Iosevka Nerd Font (includes icon glyphs for waybar)
      # Default sansSerif: Inter
      # Default serif: Noto Serif
      # Default emoji: Noto Color Emoji
      # Override in host configuration with:
      # hyprflake.fonts.monospace = {
      #   name = "JetBrainsMono Nerd Font";
      #   package = pkgs.nerd-fonts.jetbrains-mono;
      # };

      # Cursor theme
      cursor = {
        name = lib.mkDefault "Adwaita";
        size = lib.mkDefault 24;
        package = lib.mkDefault pkgs.adwaita-icon-theme;
      };

      # Keyboard layout and variant
      keyboard = {
        layout = lib.mkDefault "us";
        variant = lib.mkDefault "";  # examples: "colemak", "dvorak", "altgr-intl"
      };

      # Opacity settings - applied to windows (0.0 - 1.0)
      opacity = {
        terminal = lib.mkDefault 0.9;
        desktop = lib.mkDefault 1.0;
        popups = lib.mkDefault 0.95;
        applications = lib.mkDefault 1.0;
      };

      # Theme polarity - dark, light, or either (auto-detect)
      polarity = lib.mkDefault "dark";

      # User configuration (required)
      user = {
        inherit username;
        photo = ./.face;
      };
    };
  };
}
