{ globals, pkgs, config, lib, ... }:
let
  cfg = config.server.kvm;
  username = globals.user.name;

in {

  options = {
    server.kvm = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable KVM and virt manager.";
      };

      routing = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable KVM network routing and NAT configuration.";
        };

        externalInterface = lib.mkOption {
          type = lib.types.str;
          default = "eth0";
          description = "External network interface for NAT.";
        };

        internalInterfaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "virbr1" "virbr2" "virbr3" "virbr4" "virbr5" "virbr6" "virbr7" ];
          description = "List of KVM bridge interfaces for internal networks.";
        };

        proxyArpInterfaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "List of interfaces to enable proxy ARP on.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {

    # Install necessary packages
    environment.systemPackages = with pkgs; [

      # keep-sorted start case=no numeric=yes
      guestfs-tools # Extra tools for accessing and modifying virtual machine disk images
      spice
      spice-gtk
      spice-protocol
      virt-manager
      virt-viewer
      virtio-win
      win-spice
      # keep-sorted end
    ];

    # Add user to libvirtd group
    users.users."${username}".extraGroups =
      [ "libvirtd" "qemu" "kvm" "qemu-libvirtd" "lxd" ];

    virtualisation = {
      libvirtd = {
        enable = true;
        allowedBridges = [ "virbr0" "br0" "virbr1" "virbr2" "virbr3" "virbr4" "virbr5" "virbr6" "virbr7" ];
        onBoot = "start";
        onShutdown = "suspend";
        # https://github.com/tompreston/qemu-ovmf-swtpm
        # qemu = {
        #   swtpm.enable = true;
        #   ovmf.enable = true;
        #   ovmf.packages = [ pkgs.OVMFFull.fd ];
        # };
      };

      spiceUSBRedirection.enable = true;

    };

    # Optional routing configuration
    boot.kernel.sysctl = lib.mkIf cfg.routing.enable ({
      # Enable IP forwarding
      "net.ipv4.ip_forward" = 1;
      # controls whether packets traversing a Linux bridge will be passed through iptables' FORWARD chain. When set to 1 (enabled), it allows iptables rules to affect bridged (as opposed to just routed) traffic.
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.ipv4.conf.all.forwarding" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.ipv4.conf.all.proxy_arp" = lib.mkIf (cfg.routing.proxyArpInterfaces != []) 1;
    } // lib.listToAttrs (map (iface: {
      name = "net.ipv4.conf.${iface}.proxy_arp";
      value = 1;
    }) cfg.routing.proxyArpInterfaces));

    networking = lib.mkIf cfg.routing.enable {
      nat = {
        enable = true;
        inherit (cfg.routing) externalInterface;
        # Note
        # - for every routed network created in Terraform, you need to add a new internal interface here
        # - and a static route needs to be added to the LAN router for the new network
        inherit (cfg.routing) internalInterfaces;
      };
      firewall = {
        enable = true;
        allowPing = true;
        allowedTCPPorts = [ ]; # Empty since we're allowing all traffic
        allowedUDPPorts = [ ]; # Empty since we're allowing all traffic
        extraCommands = lib.mkBefore ''
          # Allow all incoming and outgoing traffic on all interfaces
          iptables -A INPUT -j ACCEPT
          iptables -A OUTPUT -j ACCEPT
          iptables -A FORWARD -j ACCEPT
        '';
      };
    };

  };
}

