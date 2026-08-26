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
    ./gpu.nix # Intel iGPU hardware video acceleration
    ./power.nix # CPU frequency ceiling (thermal/fan-noise cap)
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

    firewall = {
      # Open NFS ports for the K8s subnet. NixOS does not auto-open these.
      allowedTCPPorts = [
        111
        2049
      ];
      allowedUDPPorts = [
        111
        2049
      ];

      # Isolate the ts-exit VM (libvirt's default NAT network, virbr0 /
      # 192.168.122.0/24) from the home LAN. ts-exit runs Tailscale as a
      # shared exit node for a friend's tailnet, so it must only ever reach
      # the internet, never srv's own LAN devices -- libvirt's own
      # nftables table (`ip libvirt_network`) permits virbr0 -> anywhere
      # unconditionally, so this drop has to live outside that table. A
      # `drop` in any base chain attached to the forward hook is final
      # regardless of that chain's priority relative to libvirt's, so this
      # is sufficient on its own without needing to out-race libvirt's
      # chain. SSH into the VM goes over its own tailscale0 interface
      # (firewalled in the guest), not routed through here.
      extraForwardRules = ''
        ip saddr 192.168.122.0/24 ip daddr 192.168.168.0/23 drop
      '';

      # libvirt's default NAT network (virbr0) is used for the first time by
      # ts-exit -- darkstar attaches to br0 instead, so nothing on srv
      # previously exercised virbr0's dnsmasq. server.kvm's trustedBridgePrefix
      # wildcard only covers Terraform's "vbr-*" per-cluster networks, not
      # libvirt's own "virbr0", so nixos-fw's default-drop INPUT policy was
      # silently eating virbr0 guests' DHCP/DNS requests to the host's dnsmasq
      # (confirmed live: guest fell back to a 169.254.x.x link-local address
      # until this was added). Scoped to just those two ports rather than
      # trusting the whole interface, matching this repo's usual
      # minimum-privilege posture (see server.postgres.allowedCIDRs).
      extraInputRules = ''
        iifname "virbr0" udp dport { 53, 67 } accept
        iifname "virbr0" tcp dport 53 accept
      '';
    };
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
    gum
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
