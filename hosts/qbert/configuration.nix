{ config, pkgs, inputs, hostname, username, globals, ... }:

{
  # Import hardware configuration
  imports = [
    ./hardware-configuration.nix  # Hardware-specific settings (generated with --no-filesystems)
    ./disko.nix                   # Disko declarative disk partitioning
    ./boot.nix                    # Bootloader with bcachefs support
    ./gpu.nix                     # AMD GPU configuration

    # Auto-import all modules
    ../../modules
  ];

  # Networking
  networking.hostName = hostname;

  # Time zone and localization (from globals)
  time.timeZone = globals.defaults.timeZone;
  i18n.defaultLocale = globals.defaults.locale;

  # Enable archetypes
  archetypes.workstation.enable = true;

  # Hyprflake Configuration
  # All options explicitly set to demonstrate available customization
  # Values marked (default) can be removed to use hyprflake's defaults
  # Customize these values to personalize your desktop environment
  hyprflake = {
    # Color scheme - Base16 theme name
    # Browse available schemes: https://tinted-theming.github.io/base16-gallery/
    colorScheme = "catppuccin-mocha";  # (default)

    # Wallpaper - local file path
    # Default: Catppuccin Mocha galaxy-waves.jpg (included in hyprflake)
    # To override, uncomment and set path:
    # wallpaper = ./path/to/your-wallpaper.png;

    # Font configuration - using hyprflake defaults
    # Default monospace: Iosevka Nerd Font (includes icon glyphs for waybar)
    # Default sansSerif: Inter
    # Default serif: Noto Serif
    # Default emoji: Noto Color Emoji
    # To override, uncomment and customize:
    # fonts = {
    #   monospace = {
    #     name = "JetBrainsMono Nerd Font";
    #     package = pkgs.nerd-fonts.jetbrains-mono;
    #   };
    # };

    # Cursor theme
    cursor = {
      name = "Adwaita";  # (hyprflake default: "catppuccin-mocha-dark-cursors")
      size = 24;  # (default)
      package = pkgs.adwaita-icon-theme;  # (hyprflake default: pkgs.catppuccin-cursors.mochaDark)
    };

    # Keyboard layout and variant
    keyboard = {
      layout = "us";  # (default)
      variant = "";   # (default) - examples: "colemak", "dvorak", "altgr-intl"
    };

    # Opacity settings - applied to windows (0.0 - 1.0)
    opacity = {
      terminal = 0.9;      # (default)
      desktop = 1.0;       # (default)
      popups = 0.95;       # (default)
      applications = 1.0;  # (default)
    };

    # Theme polarity - dark, light, or either (auto-detect)
    polarity = "dark";  # (default)

    # User configuration (required)
    user = {
      username = username;
      photo = ./.face;
    };
  };
}
