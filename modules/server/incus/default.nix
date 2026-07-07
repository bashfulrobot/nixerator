{
  globals,
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.server.incus;
  # Path where render-secrets materializes the browser client certificate from
  # the `incus-client.crt` 1Password Document. Read at Nix eval time so the
  # cert lands in the preseed without going through secrets.json (which can't
  # embed multi-line PEM values). Absent before first render-secrets run →
  # certificates list is empty and no trust entry is added.
  _clientCertPath = "${globals.user.homeDirectory}/.config/incus/client.crt";
  _clientCert =
    if builtins.pathExists _clientCertPath then builtins.readFile _clientCertPath else null;

  # Build a desktop launcher that opens an Incus web UI at `url` via xdg-open.
  # Shared by the local daemon (loopback) and any remote peers (over Tailscale)
  # so both kinds of launcher stay identical apart from name/label/target.
  mkIncusLauncher =
    {
      name,
      desktopName,
      comment,
      url,
    }:
    pkgs.makeDesktopItem {
      inherit name desktopName comment;
      genericName = "Container and VM Manager";
      exec = "${pkgs.xdg-utils}/bin/xdg-open ${url}";
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
    };
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

      desktopEntry = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install a desktop launcher that opens the web UI in the default browser. Turn off on headless hosts.";
      };

      remotes = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "Short id used for the .desktop filename (incus-web-ui-<name>).";
              };
              label = lib.mkOption {
                type = lib.types.str;
                description = ''Launcher display name, e.g. "Incus (srv)".'';
              };
              address = lib.mkOption {
                type = lib.types.str;
                description = ''
                  Host or IP serving the remote Incus UI, reached at
                  https://<address>:<ui.port>. Use a Tailscale IP or MagicDNS name
                  so the launcher resolves from anywhere on the tailnet.
                '';
              };
            };
          }
        );
        default = [ ];
        example = lib.literalExpression ''
          [ { name = "srv"; label = "Incus (srv)"; address = "100.64.187.14"; } ]
        '';
        description = ''
          Desktop launchers for remote Incus web UIs (peer hosts over Tailscale).
          Independent of ui.enable/desktopEntry, which govern only this host's own
          launcher: a workstation can front peers' UIs without serving its own.
          All remotes are assumed to listen on ui.port.
        '';
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
          Backing driver for the default storage pool. The srv host root is
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

    trustedBridges = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "spitfire" ];
      description = ''
        Extra Incus-managed bridges to trust in the host firewall, on top of the
        managed bridge (network.name). Use this for bridges created outside Nix
        — e.g. the per-cluster NAT bridge the terraform-talos module makes, named
        after the cluster (cluster_name).

        Why this is needed: the NixOS firewall (table inet nixos-fw) hooks the
        input chain with policy drop and only trusts loopback. Incus adds its own
        accept rules in table inet incus, but both tables filter input
        independently and a drop in either is fatal, so nixos-fw silently drops
        DHCP/DNS from instances before dnsmasq on the bridge can answer. The
        result is instances that boot fine but never get a lease (anything trying
        to reach them sees "no route to host"). Trusting the bridge interface
        lets that intra-bridge traffic through. These are internal NAT bridges
        carrying only local instance traffic, so trusting them adds no external
        exposure.
      '';
    };

    trustedBridgePrefix = lib.mkOption {
      type = lib.types.str;
      default = "tbr-";
      example = "tbr-";
      description = ''
        Interface-name prefix for Terraform-created per-cluster Incus bridges.
        Any bridge whose name starts with this prefix is trusted in the host
        firewall with a single wildcard rule (iifname "<prefix>*" accept), so new
        clusters need no change here as long as their bridge follows the
        convention. The terraform-talos module names its bridge
        <bridge_prefix><cluster_name> (e.g. tbr-spitfire); keep this equal to
        that bridge_prefix. Set to "" to disable the wildcard and trust bridges
        only via the explicit trustedBridges list. See trustedBridges for why
        this firewall trust is needed at all.
      '';
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

        # Browser client certificate trusted for the web UI and API. Read
        # directly from the path where render-secrets materializes it; absent
        # before the first render-secrets run so the list is empty and no
        # trust entry is added (safe for bootstrap).
        certificates = lib.optional (_clientCert != null) {
          name = "browser";
          type = "client";
          certificate = _clientCert;
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

    # The upstream module's incus-preseed unit is not idempotent: `incus admin
    # init --preseed` exits 1 if a certificate in the preseed is already in the
    # trust store, even though storage pools/networks/profiles re-apply cleanly.
    # That fails every subsequent rebuild once the "browser" cert has been
    # trusted once. Wrap the same command (re-deriving cfg.package and the
    # preseed YAML the way the upstream module does) and tolerate only that one
    # already-trusted error, so a real preseed failure still fails the unit.
    systemd.services.incus-preseed.script = lib.mkForce ''
      set +e
      out=$(${config.virtualisation.incus.package}/bin/incus admin init --preseed \
        <${
          (pkgs.formats.yaml { }).generate "incus-preseed.yaml" config.virtualisation.incus.preseed
        } 2>&1)
      rc=$?
      echo "$out"
      if [ "$rc" -ne 0 ] && ! echo "$out" | grep -q 'already in trust store'; then
        exit "$rc"
      fi
      exit 0
    '';

    # Open the Incus API/UI port on all interfaces. The daemon already binds
    # all interfaces (core.https_address above), so this makes it reachable
    # on LAN, Tailscale, and loopback without per-host firewall overrides.
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.ui.enable [ cfg.ui.port ];

    # Trust the Incus NAT bridges so instances can reach the host's dnsmasq for
    # DHCP/DNS. Without this the nixos-fw input chain (policy drop) silently eats
    # the instances' DHCP requests even though Incus's own nftables table accepts
    # them, and instances boot but never get an address. Covers the managed
    # bridge plus any explicitly-named Terraform bridges (trustedBridges).
    networking.firewall.trustedInterfaces = [ cfg.network.name ] ++ cfg.trustedBridges;

    # And trust every per-cluster bridge sharing the naming convention with one
    # wildcard rule, so a new Terraform cluster (e.g. tbr-darkstar) works without
    # editing this module. trustedInterfaces can't express a wildcard, so this
    # goes in as a raw input rule.
    networking.firewall.extraInputRules = lib.optionalString (cfg.trustedBridgePrefix != "") ''
      iifname "${cfg.trustedBridgePrefix}*" accept comment "trust Incus per-cluster bridges"
    '';

    # Desktop launchers for the web UI. The local entry opens this host's daemon
    # over loopback (always works on the host). Each ui.remotes entry adds a
    # launcher for a peer's UI over Tailscale, so a workstation can reach srv's
    # UI without leaving the desktop. The browser client certificate is
    # declared in the preseed above; import ~/.config/incus/client.pfx into
    # the browser once (render-secrets materializes it from 1Password).
    environment.systemPackages =
      lib.optional (cfg.ui.enable && cfg.ui.desktopEntry) (mkIncusLauncher {
        name = "incus-web-ui";
        desktopName = "Incus";
        comment = "Manage Incus system containers and virtual machines";
        url = "https://localhost:${toString cfg.ui.port}";
      })
      ++ map (
        r:
        mkIncusLauncher {
          name = "incus-web-ui-${r.name}";
          desktopName = r.label;
          comment = "Open the Incus web UI on ${r.name} (${r.address})";
          url = "https://${r.address}:${toString cfg.ui.port}";
        }
      ) cfg.ui.remotes;
  };
}
