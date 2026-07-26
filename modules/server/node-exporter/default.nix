{
  config,
  lib,
  ...
}:
let
  cfg = config.server.nodeExporter;
in
{
  options = {
    server.nodeExporter = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Run prometheus-node-exporter so an off-host Prometheus can see this
          machine.

          A hypervisor is invisible to anything scraping inside its own guests.
          The Kubernetes nodes on srv each run a node-exporter of their own, so
          Grafana had per-VM metrics and nothing at all for the box underneath:
          no load, no iowait, no package temperature, no disk utilisation. When
          the host thermally throttled, every in-cluster signal was a downstream
          symptom (failed probes, evicted pods) and the actual cause only showed
          up as audible fan noise.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 9100;
        description = "Port node-exporter listens on.";
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = ''
          Address to bind. Defaults to all interfaces because the scraper is
          usually a pod on another subnet; openFirewallFrom is what actually
          bounds who can reach it.
        '';
      };

      openFirewallFrom = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "192.168.168.0/23" ];
        description = ''
          Source CIDRs allowed to reach the exporter port. Empty means no
          firewall rule is added at all, which on a host with the NixOS firewall
          enabled means nothing off-box can scrape it.

          This is a source-restricted rule rather than an entry in
          networking.firewall.allowedTCPPorts because node-exporter is an
          unauthenticated read of host state: kernel version, filesystem layout,
          every mountpoint, every network device. Fine for the scraper, not
          something to hand to the whole LAN.
        '';
      };

      extraCollectors = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "hwmon"
          "thermal_zone"
          "rapl"
          "systemd"
          "processes"
        ];
        description = ''
          Collectors to enable on top of the defaults.

          hwmon, thermal_zone and rapl are the thermal story: package
          temperature, per-zone trip points, and the running energy counter that
          shows when the CPU is being held at its sustained power limit rather
          than merely being busy. diskstats, meminfo, loadavg, pressure and nfsd
          are already on by default, so they are not repeated here.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus.exporters.node = {
      enable = true;
      inherit (cfg) port listenAddress;
      enabledCollectors = cfg.extraCollectors;
      # openFirewall would punch a hole for every source address. The
      # source-scoped rule below replaces it.
      openFirewall = false;
    };

    # nftables syntax, not iptables: the nftables firewall backend asserts
    # outright on networking.firewall.extraCommands. extraInputRules is spliced
    # into the input chain ahead of the final drop.
    networking.firewall.extraInputRules = lib.mkIf (cfg.openFirewallFrom != [ ]) (
      lib.concatMapStringsSep "\n" (
        cidr: "ip saddr ${cidr} tcp dport ${toString cfg.port} accept"
      ) cfg.openFirewallFrom
    );
  };
}
