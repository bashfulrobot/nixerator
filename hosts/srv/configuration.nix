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

    interfaces.enp3s0 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "192.168.168.1";
          prefixLength = 23;
        }
      ];
    };

    defaultGateway = {
      address = "192.168.169.1";
      interface = "enp3s0";
    };

    # Macvlan sibling for K8s NFS access. Macvlan children (K8s VMs) cannot ARP-resolve the
    # parent NIC's IP (192.168.168.1) due to kernel macvlan isolation. A macvlan sibling on
    # the same parent gets its own MAC and CAN communicate peer-to-peer with the K8s VMs.
    macvlans."mv-k8s" = {
      interface = "enp3s0";
      mode = "bridge";
    };

    interfaces."mv-k8s" = {
      ipv4.addresses = [
        {
          address = "192.168.169.200";
          prefixLength = 23;
        }
      ];
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

    # Source-based routing: replies originating from 192.168.169.200 must leave via mv-k8s so
    # the response MAC is the macvlan sibling's MAC. Without this, Linux routes NFS replies via
    # enp3s0 (the parent MAC), which macvlan children silently drop. The ip rule here covers
    # the NFS server reply direction. The mv-k8s-routes unit adds a /24 main-table route that
    # covers the forward direction (srv→k8s), so kubectl and ping also work.
    localCommands = ''
      ip rule add from 192.168.169.200 lookup 200 priority 100 2>/dev/null || true
      ip rule add iif tailscale0 lookup 200 priority 99 2>/dev/null || true
    '';
  };

  # Routing for mv-k8s: runs after network-setup so mv-k8s has its address.
  systemd.services."mv-k8s-routes" = {
    description = "Populate routing tables for mv-k8s macvlan sibling";
    after = [ "network-setup.service" ];
    requires = [ "network-setup.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Table 200: used by the ip rule "from 192.168.169.200 lookup 200" so that
      # NFS reply packets (src 192.168.169.200) leave via mv-k8s.
      ${pkgs.iproute2}/bin/ip route replace 192.168.168.0/23 dev mv-k8s src 192.168.169.200 table 200
      ${pkgs.iproute2}/bin/ip route replace default via 192.168.169.1 dev enp3s0 table 200

      # Main table: route all 192.168.168.x traffic via mv-k8s. A /24 beats the
      # /23-via-enp3s0, so packets to macvlan children (VIP .9, CPs .10-.12,
      # workers .20-.21, Cilium LB .240/28) leave from the sibling MAC, not the
      # parent MAC (which children silently drop). 192.168.168.1 (srv) is a local
      # address and is unaffected.
      ${pkgs.iproute2}/bin/ip route replace 192.168.168.0/24 dev mv-k8s src 192.168.169.200
    '';
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
