{
  hostname,
  globals,
  pkgs,
  ...
}:

{
  # Import hardware configuration
  imports = [
    ./hardware-configuration.nix # Hardware-specific settings
    ./boot.nix # Bootloader configuration
    ./modules.nix # Module configuration
  ];

  # Networking
  networking = {
    hostName = hostname;

    # Static IP configuration
    useDHCP = false;

    nameservers = [
      "1.1.1.1"
      "9.9.9.9"
    ];

    hosts = {
      "192.168.168.1" = [
        "srv"
        "srv.goat-cloud.ts.net"
      ];
      "127.0.0.1" = [ "localhost" ];
    };

    # enp3s0 is now a bridge member, not directly addressed — br0 carries the
    # host's L3 config instead. libvirt VMs (darkstar's Talos nodes) attach to
    # br0 directly, appearing as first-class LAN devices, same as the previous
    # Incus macvlan setup. Unlike macvlan, a real bridge lets the host talk to
    # its own bridged VMs directly, so the previous mv-k8s macvlan sibling +
    # policy-routing workaround (needed only to work around that macvlan
    # limitation) is retired entirely below.
    bridges."br0".interfaces = [ "enp3s0" ];

    interfaces.enp3s0.useDHCP = false;
    interfaces."br0" = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "192.168.168.1";
          prefixLength = 23;
        }
        # NFS server address for K8s CSI provisioning (nfs-darkstar
        # StorageClass). Previously bound to the mv-k8s macvlan sibling;
        # now lives directly on the bridge since the host can reach VMs
        # across br0 without a sibling device.
        {
          address = "192.168.169.200";
          prefixLength = 23;
        }
      ];
    };

    defaultGateway = {
      address = "192.168.169.1";
      interface = "br0";
    };

    # Open NFS ports for the K8s subnet. NixOS does not auto-open these.
    firewall.allowedTCPPorts = [
      111
      2049
    ];
    firewall.allowedUDPPorts = [
      111
      2049
    ];
  };

  # Localization (from globals)
  time.timeZone = globals.defaults.timeZone;
  i18n.defaultLocale = globals.defaults.locale;

  # User configuration
  users.users.${globals.user.name} = {
    isNormalUser = true;
    description = globals.user.fullName;
    group = globals.user.name;
    extraGroups = [
      "docker"
      "wheel"
      "networkmanager"
    ];
    shell = pkgs.${globals.preferences.shell};
  };

  users.groups.${globals.user.name} = { };

  # Passwordless sudo for wheel group (enables CLI rebuilds from Claude Code / zellij)
  security.sudo.wheelNeedsPassword = false;

  # System packages
  environment.systemPackages = with pkgs; [
    bat
    bottom
    cloud-utils
    curl
    dust
    eza
    fd
    filebot
    gdu
    git
    git-crypt
    gnumake
    gnupg
    just
    keychain
    kubectl
    nixfmt
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
