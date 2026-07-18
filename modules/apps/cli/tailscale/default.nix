{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.tailscale;
in
{
  options = {
    apps.cli.tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable tailscale mesh VPN.";
    };

    apps.cli.tailscale.preferLanCidrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "192.168.168.0/23" ];
      description = ''
        Subnet CIDRs that are advertised as Tailscale subnet routes but which
        this host is ALSO physically connected to (e.g. srv advertises the home
        LAN 192.168.168.0/23, and qbert sits on that same LAN over WiFi).

        With `--accept-routes` on, the accepted subnet route lands in Tailscale's
        routing table 52, and its policy rule (priority 5270) outranks the main
        table -- so the host routes replies to LAN peers back over tailscale0
        instead of the direct LAN link. That asymmetric return path gets dropped
        at the routing layer before the firewall, making the host unreachable on
        its LAN IP (inbound SSH/mosh/ping fail) even though Tailscale works.

        For each CIDR here, a policy rule at priority 5260 (just above Tailscale's
        5270) prefers the main table -- so a directly-connected LAN route wins.
        `suppress_prefixlength 0` ignores the default route in that lookup, so
        when the host is OFF this LAN (no connected route) the rule falls through
        to Tailscale's table 52 and the subnet stays reachable over the tailnet.
        Net effect: direct LAN when on-link, Tailscale when roaming. Requires
        accept-routes to stay enabled.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;

      # Use the regular OpenSSH daemon (system.ssh) for SSH access, NOT the
      # Tailscale SSH server (issue #107). `tailscale set --ssh=false` runs on
      # every activation via the module's tailscaled-set service, so any node
      # that previously had Tailscale SSH enabled gets it switched off, and we
      # never pass `--ssh` to `tailscale up`. Nodes are brought onto the tailnet
      # manually (OAuth / terminal login), so no auth-key auto-join is wired
      # here -- this avoids the 90-day auth-key expiry treadmill.
      extraSetFlags = [ "--ssh=false" ];
    };

    environment.systemPackages = with pkgs; [
      tailscale # zero-config VPN
    ];

    # https://github.com/NixOS/nixpkgs/issues/180175#issuecomment-2372305193
    systemd.services.tailscaled.after = [
      "NetworkManager-wait-online.service"
    ];

    # Install policy-routing rules so directly-connected LAN subnets win over
    # the same subnet accepted as a Tailscale route (see preferLanCidrs above).
    # The rule is resolved per-packet, so it does not depend on the interface
    # being up when the unit runs; ordering after tailscaled just ensures
    # Tailscale's own rules (incl. the 5270 lookup) already exist. `ip rule del`
    # before `add` keeps it idempotent across rebuilds and clears any rule left
    # by a manual `ip rule add` at the same priority.
    systemd.services.tailscale-prefer-lan = lib.mkIf (cfg.preferLanCidrs != [ ]) {
      description = "Prefer direct LAN routes over accepted Tailscale subnet routes";
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "tailscale-prefer-lan-start" ''
          set -eu
          prio=5260
          for cidr in ${lib.concatStringsSep " " cfg.preferLanCidrs}; do
            ${pkgs.iproute2}/bin/ip rule del to "$cidr" priority "$prio" lookup main suppress_prefixlength 0 2>/dev/null || true
            ${pkgs.iproute2}/bin/ip rule add to "$cidr" priority "$prio" lookup main suppress_prefixlength 0
            prio=$((prio + 1))
          done
        '';
        ExecStop = pkgs.writeShellScript "tailscale-prefer-lan-stop" ''
          prio=5260
          for cidr in ${lib.concatStringsSep " " cfg.preferLanCidrs}; do
            ${pkgs.iproute2}/bin/ip rule del to "$cidr" priority "$prio" lookup main suppress_prefixlength 0 2>/dev/null || true
            prio=$((prio + 1))
          done
        '';
      };
    };
  };
}
