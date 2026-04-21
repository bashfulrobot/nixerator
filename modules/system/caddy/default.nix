{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.system.caddy;
  certDir = "/var/lib/caddy/.tailscale";
  certFile = "${certDir}/${cfg.tailnetHostname}.crt";
  keyFile = "${certDir}/${cfg.tailnetHostname}.key";
in
{
  options.system.caddy = {
    enable = lib.mkEnableOption "system Caddy reverse proxy with Tailscale HTTPS";

    openFirewall = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = ''
        External TCP ports to open in the firewall for Caddy vhosts.
        App modules contribute their external ports here.
      '';
    };

    tailnetHostname = lib.mkOption {
      type = lib.types.str;
      default = "${config.networking.hostName}.goat-cloud.ts.net";
      description = "Tailnet MagicDNS hostname used for Tailscale HTTPS cert provisioning.";
    };

    certFile = lib.mkOption {
      type = lib.types.str;
      default = certFile;
      readOnly = true;
      description = "Absolute path to the Tailscale-issued cert (set by this module).";
    };

    keyFile = lib.mkOption {
      type = lib.types.str;
      default = keyFile;
      readOnly = true;
      description = "Absolute path to the Tailscale-issued key (set by this module).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      email = "caddy@localhost";
    };

    services.tailscale.permitCertUid = "caddy";

    networking.firewall.allowedTCPPorts = cfg.openFirewall;

    systemd.tmpfiles.rules = [
      "d ${certDir} 0750 caddy caddy -"
    ];

    systemd.services.caddy-tailscale-cert = {
      description = "Provision/renew Tailscale TLS certificate for Caddy";
      after = [
        "tailscaled.service"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      requires = [ "tailscaled.service" ];
      before = [ "caddy.service" ];
      wantedBy = [ "caddy.service" ];
      path = [ pkgs.tailscale ];
      serviceConfig = {
        Type = "oneshot";
        User = "caddy";
        Group = "caddy";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "caddy-tailscale-cert" ''
          set -euo pipefail
          ${pkgs.tailscale}/bin/tailscale cert \
            --cert-file=${certFile} \
            --key-file=${keyFile} \
            ${cfg.tailnetHostname}
        '';
      };
    };

    systemd.timers.caddy-tailscale-cert = {
      description = "Renew Tailscale TLS certificate for Caddy";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
    };
  };
}
