{ hostname, globals, pkgs, ... }:

{
  # Import hardware configuration
  imports = [
    ./hardware-configuration.nix  # Hardware-specific settings
    ./boot.nix                    # Bootloader configuration
    ./modules.nix                 # Module configuration
  ];

  # Networking
  networking = {
    hostName = hostname;

    # Static IP configuration
    useDHCP = false;

    nameservers = [ "1.1.1.1" "9.9.9.9" ];

    hosts = {
      "192.168.168.1" = ["srv" "srv.goat-cloud.ts.net"];
      "127.0.0.1" = ["localhost"];
    };

    interfaces.enp3s0 = {
      useDHCP = false;
      ipv4.addresses = [{
        address = "192.168.168.1";
        prefixLength = 23;
      }];
    };

    defaultGateway = {
      address = "192.168.169.1";
      interface = "enp3s0";
    };
  };

  # Localization (from globals)
  time.timeZone = "America/Vancouver";
  i18n.defaultLocale = globals.defaults.locale;

  # User configuration
  users.users.${globals.user.name} = {
    isNormalUser = true;
    description = globals.user.fullName;
    group = globals.user.name;
    extraGroups = [ "docker" "wheel" "kvm" "qemu-libvirtd" "libvirtd" "networkmanager" ];
    shell = pkgs.${globals.preferences.shell};
  };

  users.groups.${globals.user.name} = {};

  # System packages
  environment.systemPackages = with pkgs; [
    bat
    bottom
    cloud-utils
    curl
    dust
    eza
    fd
    gdu
    git
    git-crypt
    gnumake
    gnupg
    just
    nixfmt-rfc-style
    pass
    pinentry-tty
    ripgrep
    shadowenv
    tmux
    tree
    wakeonlan
    wget
  ];
}
