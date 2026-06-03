{ lib
, pkgs
, config
, globals
, ...
}:

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
        # Default monospace: Iosevka Nerd Font (includes icon glyphs for the shell)
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
        # Use ghostty as the default terminal (overrides hyprflake's kitty default)
        terminal.package = pkgs.ghostty;

        # Keyboard layout and variant
        keyboard = {
          layout = lib.mkDefault "us";
          variant = lib.mkDefault ""; # examples: "colemak", "dvorak", "altgr-intl"
        };

        # Idle management configuration (handled by DankMaterialShell)
        # Controls screen locking, display power management, and suspend timeouts
        idle = {
          lockTimeout = lib.mkDefault 300; # Lock screen after 5 minutes
          # dpmsTimeout intentionally not set: hyprflake's default is 0 (disabled).
          # OS-driven DPMS is unreliable across GPU/cable/monitor combinations.
          # Opt back in per host with `hyprflake.desktop.idle.dpmsTimeout = 360;` if needed.
          suspendTimeout = lib.mkDefault 600; # Suspend after 10 minutes (set to 0 to disable)
        };
      };

      # System configuration - System-level configuration
      system = {
        # Enable Plymouth boot splash theme
        plymouth.enable = lib.mkDefault true;

        # Power management configuration
        # Desktop defaults - hosts can override for laptop-specific needs
        power = {
          # profilesBackend is intentionally not set here. hyprflake derives it
          # from hyprflake.system.isLaptop: "power-profiles-daemon" on laptops
          # (so the DMS power-profile applet works), "none" on desktops.

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
            idleAction = lib.mkDefault "ignore"; # Handled by DankMaterialShell
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

      # Note: the old hyprshell alt-tab switcher was retired. DMS offers a
      # window overview/exposé (dms ipc hypr toggleOverview), not a classic
      # alt-tab; a traditional alt-tab would be a Hyprland cyclenext keybind.

      # User configuration (required)
      user = {
        username = globals.user.name;
        photo = ./.face;
      };
    };

    # Stylix font configuration - Apple fonts (SF Pro, SF Mono, New York)
    # To revert to defaults, comment out this stylix.fonts block:
    #   monospace: DejaVu Sans Mono
    #   sansSerif: DejaVu Sans
    #   serif: DejaVu Serif
    #   emoji: Noto Color Emoji
    # Force Stylix's Kvantum theme to win over Home Manager's Qt module,
    # which also writes kvantum.kvconfig when qt.style.name = "kvantum"
    # nautilus-open-any-terminal now sets NAUTILUS_4_EXTENSION_DIR upstream
    environment.pathsToLink = [ "/share/nautilus-python/extensions" ];

    # Ghostty ships its own Nautilus extension (share/nautilus-python/extensions/ghostty.py).
    # Disable hyprflake's nautilus-open-any-terminal to avoid duplicate "Open in Ghostty"
    # entries; the package itself is stubbed via overlay in lib/mkHost.nix so the .py
    # cannot be picked up from hyprflake's environment.systemPackages contribution.
    programs.nautilus-open-any-terminal.enable = lib.mkForce false;

    home-manager.users.${globals.user.name} = {
      # Adopt new 26.05 default: gtk4 no longer inherits gtk.theme.
      # mkForce to win over stylix's HM gtk module, which now sets
      # gtk.gtk4.theme = config.gtk.theme (otherwise: "defined both null
      # and not null" eval conflict).
      gtk.gtk4.theme = lib.mkForce null;

      xdg.configFile."Kvantum/kvantum.kvconfig".source = lib.mkForce (
        pkgs.writeText "kvantum.kvconfig" ''
          [General]
          theme=Base16Kvantum
        ''
      );
    };

    # kmscon is not used on any host, but Stylix's kmscon target auto-enables
    # and sets services.kmscon.{extraConfig,fonts} — both removed in nixpkgs
    # 26.05, which hard-fails evaluation. Disable the unused target.
    stylix.targets.kmscon.enable = false;

    stylix.fonts = {
      monospace = {
        name = lib.mkForce "SFMono Nerd Font";
        package = lib.mkForce config.system.apple-fonts.packages.sf-mono-nerd;
      };
      sansSerif = {
        name = lib.mkForce "SF Pro Display";
        package = lib.mkForce config.system.apple-fonts.packages.sf-pro;
      };
      serif = {
        name = lib.mkForce "New York";
        package = lib.mkForce config.system.apple-fonts.packages.ny;
      };
    };
  };
}
