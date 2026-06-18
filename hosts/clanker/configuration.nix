{
  hostname,
  globals,
  pkgs,
  ...
}:

{
  # Import hardware configuration. NO `../../modules` auto-import: clanker is a
  # headless box and follows the srv pattern of manual imports + direct enables
  # (see hosts/srv/modules.nix). Auto-importing pulls in desktop modules that
  # place definitions under the `hyprflake.*`/`stylix.*` namespaces inside
  # disabled `mkIf` branches, which the module system still type-checks against
  # option namespaces clanker never declares.
  imports = [
    ./hardware-configuration.nix # Hardware-specific settings
    ./boot.nix # Bootloader configuration
    ./vm.nix # VM guest tuning
    ./modules.nix # Module configuration
  ];

  # Networking (simple DHCP for a VM)
  networking = {
    hostName = hostname;
    networkmanager.enable = true;
  };

  # Localization (from globals)
  time.timeZone = globals.defaults.timeZone;
  i18n.defaultLocale = globals.defaults.locale;

  # User configuration (defined here since there is no core suite to do it)
  users.users.${globals.user.name} = {
    isNormalUser = true;
    description = globals.user.fullName;
    group = globals.user.name;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
    ];
    shell = pkgs.${globals.preferences.shell};
  };

  users.groups.${globals.user.name} = { };

  # Passwordless sudo for wheel group (enables non-interactive `just rebuild`
  # from Claude Code / zellij)
  security.sudo.wheelNeedsPassword = false;

  # Boot straight into a logged-in TTY1 as the primary user. fish's login hook
  # (see home.nix) `exec sway`s on TTY1. No display manager, no greeter.
  services.getty.autologinUser = globals.user.name;

  # System packages (minimal base set, including the 1Password CLI)
  environment.systemPackages = with pkgs; [
    _1password-cli
    bat
    curl
    eza
    fd
    git
    just
    ripgrep
    tree
    wget
  ];

  # Basic fonts so screenshots aren't tofu
  fonts.packages = with pkgs; [
    dejavu_fonts
    nerd-fonts.iosevka
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
}
