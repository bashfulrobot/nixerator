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

    ui.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Serve the Incus web UI (the virt-manager replacement) on the local Unix socket / HTTPS listener.";
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
        storage_pools = [
          {
            name = "default";
            driver = cfg.storage.driver;
            # Loop-backed pools need a size; the dir driver must not carry one.
            config = lib.optionalAttrs (cfg.storage.driver != "dir") {
              size = cfg.storage.size;
            };
          }
        ];

        networks = [
          {
            name = cfg.network.name;
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
  };
}
