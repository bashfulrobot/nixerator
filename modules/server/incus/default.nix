{
  globals,
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.server.incus;
in
{
  options.server.incus = {
    enable = lib.mkEnableOption "Incus system containers and VMs (replaces the libvirt/KVM stack)";

    ui = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Serve the Incus web UI (the virt-manager replacement) and open the HTTPS API listener it needs.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8443;
        description = "Port for the Incus HTTPS API / web UI listener.";
      };

      tailscaleInterface = lib.mkOption {
        type = lib.types.str;
        default = "tailscale0";
        description = ''
          Interface the UI port is firewall-restricted to. The daemon listens on
          all interfaces, but only this one is allowed through the firewall, so
          the UI is reachable over the tailnet (and loopback) and nowhere else.
        '';
      };

      desktopEntry = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install a desktop launcher that opens the web UI in the default browser. Turn off on headless hosts.";
      };
    };

    storage = {
      driver = lib.mkOption {
        type = lib.types.enum [
          "btrfs"
          "zfs"
          "dir"
        ];
        default = "btrfs";
        description = ''
          Backing driver for the default storage pool. The qbert host root is
          ext4, so btrfs/zfs are created as a loop-backed pool (a single image
          file under /var/lib/incus) which still gives snapshots and
          copy-on-write clones that Incus and Terraform lean on. `dir` is the
          plain no-snapshot fallback.
        '';
      };

      size = lib.mkOption {
        type = lib.types.str;
        default = "100GiB";
        description = ''
          Size of the loop-backed pool image. Ignored for the `dir` driver,
          which grows into the host filesystem instead.
        '';
      };
    };

    network = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "incusbr0";
        description = "Name of the managed NAT bridge created for instances.";
      };

      ipv4Address = lib.mkOption {
        type = lib.types.str;
        default = "10.100.0.1/24";
        description = ''
          Address/CIDR for the managed bridge. Kept clear of the retired libvirt
          ranges (172.16.16.0/24, 192.168.122.0/24) and the srv docker-compose
          subnets so it can coexist.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Incus on NixOS is unsupported on iptables; the upstream module asserts
    # nftables. Switch the host firewall backend here so enabling this module is
    # self-contained. mkDefault lets a host that manages nftables elsewhere win.
    networking.nftables.enable = lib.mkDefault true;

    virtualisation.incus = {
      enable = true;
      ui.enable = cfg.ui.enable;

      # Declarative substrate only. Instances stay imperative (incus CLI) or are
      # provisioned by Terraform (lxc/incus provider) — preseed is additive and
      # never deletes existing entities.
      preseed = {
        # Server config. With the UI on, open the HTTPS listener that the web UI
        # and remote `incus` clients use. It binds all interfaces; the firewall
        # rule below limits reachability to the tailnet. Declaring it here means
        # it survives `incus admin init` re-runs, rebuilds, and fresh hosts.
        config = lib.optionalAttrs cfg.ui.enable {
          "core.https_address" = ":${toString cfg.ui.port}";
        };

        storage_pools = [
          {
            name = "default";
            inherit (cfg.storage) driver;
            # Loop-backed pools need a size; the dir driver must not carry one.
            config = lib.optionalAttrs (cfg.storage.driver != "dir") {
              inherit (cfg.storage) size;
            };
          }
        ];

        networks = [
          {
            inherit (cfg.network) name;
            type = "bridge";
            config = {
              "ipv4.address" = cfg.network.ipv4Address;
              "ipv4.nat" = "true";
              "ipv6.address" = "none";
            };
          }
        ];

        profiles = [
          {
            name = "default";
            devices = {
              root = {
                path = "/";
                pool = "default";
                type = "disk";
              };
              eth0 = {
                name = "eth0";
                network = cfg.network.name;
                type = "nic";
              };
            };
          }
        ];
      };
    };

    # Members of incus-admin drive the daemon without sudo. The group is created
    # by the upstream module; this just enrolls the primary user.
    users.users."${globals.user.name}".extraGroups = [ "incus-admin" ];

    # Expose the UI/API port on the tailnet interface only. The daemon binds all
    # interfaces (core.https_address above), so this firewall rule is what keeps
    # it off the LAN/Wi-Fi while leaving it reachable over Tailscale and loopback.
    networking.firewall.interfaces.${cfg.ui.tailscaleInterface}.allowedTCPPorts =
      lib.mkIf cfg.ui.enable
        [ cfg.ui.port ];

    # Desktop launcher for the web UI. Opens the local daemon's UI (loopback
    # always works on the host); browsing from another device uses the tailnet
    # address instead. First open prompts for a client certificate: run
    # `incus config trust add browser` and paste the token, a one-time per-client
    # step that can't be baked into the image.
    environment.systemPackages = lib.optional (cfg.ui.enable && cfg.ui.desktopEntry) (
      pkgs.makeDesktopItem {
        name = "incus-web-ui";
        desktopName = "Incus";
        genericName = "Container and VM Manager";
        comment = "Manage Incus system containers and virtual machines";
        exec = "${pkgs.xdg-utils}/bin/xdg-open https://localhost:${toString cfg.ui.port}";
        icon = "incus";
        categories = [
          "System"
          "Settings"
        ];
        keywords = [
          "incus"
          "container"
          "vm"
          "virtual"
          "lxc"
        ];
      }
    );
  };
}
