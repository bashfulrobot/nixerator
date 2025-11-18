{ config, pkgs, inputs, hostname, username, globals, ... }:

{
  # Import hardware configuration
  # You'll need to generate this with: nixos-generate-config --show-hardware-config > hosts/nixerator/hardware-configuration.nix
  imports = [
    ./hardware-configuration.nix
    ./boot.nix  # Bootloader configuration (update based on your system)
    ./vm.nix    # VM-specific configuration (comment out for bare metal)

    # Auto-import all modules
    ../../modules
  ];

  # Networking
  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  # Time zone and localization (from globals)
  time.timeZone = globals.defaults.timeZone;
  i18n.defaultLocale = globals.defaults.locale;

  i18n.extraLocaleSettings = {
    LC_ADDRESS = globals.defaults.locale;
    LC_IDENTIFICATION = globals.defaults.locale;
    LC_MEASUREMENT = globals.defaults.locale;
    LC_MONETARY = globals.defaults.locale;
    LC_NAME = globals.defaults.locale;
    LC_NUMERIC = globals.defaults.locale;
    LC_PAPER = globals.defaults.locale;
    LC_TELEPHONE = globals.defaults.locale;
    LC_TIME = globals.defaults.locale;
  };

  # User configuration (from globals)
  users.users.${username} = {
    isNormalUser = true;
    description = globals.user.fullName;
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.${globals.preferences.shell};
  };

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Enable fish shell (required when setting as user shell)
  programs.fish.enable = true;

  # Enable modules
  apps.cli.git.enable = true;

  # System packages
  environment.systemPackages = with pkgs; [
    wget
    curl
    just
  ] ++ [
    pkgs.${globals.preferences.editor}
  ];

  # Enable SSH
  services.openssh.enable = true;

  # Firewall
  networking.firewall.enable = true;

  # Hyprflake Configuration
  # All options explicitly set (even if they match defaults)
  # Customize these values to personalize your desktop environment
  hyprflake = {
    # Color scheme - Base16 theme name
    # Browse available schemes: https://tinted-theming.github.io/base16-gallery/
    colorScheme = "catppuccin-mocha";

    # Wallpaper - local file path
    # Default: Catppuccin Mocha galaxy-waves.jpg (included in hyprflake)
    # To override, set: hyprflake.wallpaper = ./path/to/your-wallpaper.png;
    # wallpaper = ./path/to/your-wallpaper.png;

    # Font configuration - applied system-wide via Stylix
    fonts = {
      monospace = {
        name = "JetBrains Mono";
        package = pkgs.jetbrains-mono;
      };
      sansSerif = {
        name = "Inter";
        package = pkgs.inter;
      };
      serif = {
        name = "Noto Serif";
        package = pkgs.noto-fonts;
      };
      emoji = {
        name = "Noto Color Emoji";
        package = pkgs.noto-fonts-color-emoji;
      };
    };

    # Cursor theme
    cursor = {
      name = "Adwaita";
      size = 24;
      package = pkgs.adwaita-icon-theme;
    };

    # Keyboard layout and variant
    keyboard = {
      layout = "us";
      variant = "";
    };

    # Opacity settings - applied to windows (0.0 - 1.0)
    opacity = {
      terminal = 0.9;
      desktop = 1.0;
      popups = 0.95;
      applications = 1.0;
    };

    # Theme polarity - dark, light, or either (auto-detect)
    polarity = "dark";
  };
}
