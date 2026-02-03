{ lib, pkgs, config, inputs, username, ... }:

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
    # Apple fonts for system-wide availability
    system.apple-fonts.enable = true;

    # Hyprflake Configuration
    # Centralized desktop environment configuration for all workstations
    # Individual hosts can override these settings in their configuration.nix
    hyprflake = {
      # Style configuration - Visual appearance and theming
      style = {
        # Color scheme - Base16 theme name
        # Browse available schemes: https://tinted-theming.github.io/base16-gallery/
        colorScheme = lib.mkDefault "catppuccin-mocha";

        # Wallpaper - local file path
        # Default: Catppuccin Mocha galaxy-waves.jpg (included in hyprflake)
        # Override in host configuration with:
        # hyprflake.style.wallpaper = ./path/to/your-wallpaper.png;

        # Font configuration - using hyprflake defaults
        # Default monospace: Iosevka Nerd Font (includes icon glyphs for waybar)
        # Default sansSerif: Inter
        # Default serif: Noto Serif
        # Default emoji: Noto Color Emoji

        # Cursor theme
        cursor = {
          name = lib.mkDefault "Adwaita";
          size = lib.mkDefault 24;
          package = lib.mkDefault pkgs.adwaita-icon-theme;
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
      };

      # Desktop configuration - Desktop environment behavior
      desktop = {
        # Keyboard layout and variant
        keyboard = {
          layout = lib.mkDefault "us";
          variant = lib.mkDefault "";  # examples: "colemak", "dvorak", "altgr-intl"
        };

        # Waybar auto-hide configuration
        # Automatically hides waybar when workspace is empty and shows on cursor hover at top edge
        waybar.autoHide = lib.mkDefault false;

        # Idle management configuration (hypridle)
        # Controls screen locking, display power management, and suspend timeouts
        idle = {
          lockTimeout = lib.mkDefault 300;     # Lock screen after 5 minutes
          dpmsTimeout = lib.mkDefault 360;     # Turn off display after 6 minutes
          suspendTimeout = lib.mkDefault 600;  # Suspend after 10 minutes (set to 0 to disable)
        };
      };

      # System configuration - System-level configuration
      system = {
        # Enable Plymouth boot splash theme
        plymouth.enable = lib.mkDefault true;

        # Power management configuration
        # Desktop defaults - hosts can override for laptop-specific needs
        power = {
          # No power profile backend by default (performance desktop)
          profilesBackend = lib.mkDefault "none";

          # Thermald disabled by default (enable for Intel laptops)
          thermald.enable = lib.mkDefault false;

          # Sleep configuration - defaults allow suspend/hibernate
          # Override in host configuration to disable (see qbert example)
          sleep = {
            allowSuspend = lib.mkDefault true;
            allowHibernation = lib.mkDefault true;
            hibernateDelay = lib.mkDefault null;
          };

          # Logind power event handling
          logind = {
            handlePowerKey = lib.mkDefault "poweroff";
            handleLidSwitch = lib.mkDefault "suspend";
            handleLidSwitchDocked = lib.mkDefault "ignore";
            idleAction = lib.mkDefault "ignore";  # Handled by hypridle
            idleActionSec = lib.mkDefault 0;
          };

          # Resume commands - empty by default
          resumeCommands = lib.mkDefault "";

          # Battery thresholds - null by default (TLP only)
          battery = {
            startThreshold = lib.mkDefault null;
            stopThreshold = lib.mkDefault null;
          };

          # TLP settings - empty by default
          tlp.settings = lib.mkDefault { };
        };
      };

      # Note: Hyprshell window switcher (alt-tab) is now always enabled via hyprflake

      # User configuration (required)
      user = {
        inherit username;
        photo = ./.face;
      };
    };

    # Stylix font configuration - Apple fonts (SF Pro, SF Mono, New York)
    # To revert to defaults, comment out this stylix.fonts block:
    #   monospace: DejaVu Sans Mono
    #   sansSerif: DejaVu Sans
    #   serif: DejaVu Serif
    #   emoji: Noto Color Emoji
    stylix.fonts = {
      monospace = {
        name = lib.mkForce "SFMono Nerd Font";
        package = lib.mkForce inputs.apple-fonts.packages.${pkgs.system}.sf-mono-nerd;
      };
      sansSerif = {
        name = lib.mkForce "SF Pro Display";
        package = lib.mkForce inputs.apple-fonts.packages.${pkgs.system}.sf-pro;
      };
      serif = {
        name = lib.mkForce "New York";
        package = lib.mkForce inputs.apple-fonts.packages.${pkgs.system}.ny;
      };
    };
  };
}
