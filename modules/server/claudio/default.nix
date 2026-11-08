{
  config,
  lib,
  pkgs,
  inputs,
  globals,
  ...
}:
# claudio, the phone-friendly Claude Code session manager, as a host service
# published on the tailnet. One instance (qbert) lists the others as peers and
# merges their sessions into one page; the rest only need a label.
#
# The service binds loopback and `tailscale serve` fronts it with HTTPS under
# /claudio, never a raw firewall port. Mirrors the publish pattern in
# modules/server/incident-investigator/default.nix.
let
  cfg = config.server.claudio;
in
{
  # The upstream module declares services.claudio. Imported here, not in
  # flake.nix, so a host that enables server.claudio needs nothing else.
  imports = [ inputs.claudio.nixosModules.default ];

  options.server.claudio = {
    enable = lib.mkEnableOption "claudio on this host, published on the tailnet";

    hostName = lib.mkOption {
      type = lib.types.str;
      description = "Label for this host in the merged session list.";
    };

    peers = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        mac = "https://mac.example.ts.net/claudio";
      };
      description = ''
        Other claudio instances to merge into this one's session list, as name
        to `tailscale serve` base URL. There is no auth between instances, so
        restrict the port with Tailscale ACLs.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.claudio = {
      enable = true;
      user = globals.user.name;
      listenAddr = "127.0.0.1:8787";
      inherit (cfg) hostName peers;
      # The module's default reads `pkgs.system`, which now warns at eval
      # time. Set the package here to bypass that default.
      package = inputs.claudio.packages.${pkgs.stdenv.hostPlatform.system}.default;
      # systemd services don't inherit the user's shell PATH, so "claude"
      # alone isn't found -- point at the stable per-user profile symlink
      # instead of a /nix/store path that changes every generation.
      claudeBinary = "/etc/profiles/per-user/${globals.user.name}/bin/claude";
      roots = [
        "/home/${globals.user.name}/git"
        "/home/${globals.user.name}/dev"
      ];
    };

    systemd.services.claudio-serve = {
      description = "Publish claudio on the tailnet (tailscale serve)";
      after = [
        "tailscaled.service"
        "network-online.target"
        "claudio.service"
      ];
      wants = [
        "tailscaled.service"
        "network-online.target"
      ];
      wantedBy = [ "multi-user.target" ];
      # `after = tailscaled.service` orders unit start only, and tailscaled is
      # "active" well before its ipn backend leaves NoState. `tailscale serve`
      # against a NoState backend exits 1 ("unexpected state: NoState"), so any
      # rebuild that restarts tailscaled -- most nixpkgs/systemd bumps -- loses
      # this race. Restart= does not save activation: it schedules a retry 10s
      # later, while switch-to-configuration has already seen the first start
      # fail and exits status 4, so `just qr` fails even though the serve lands
      # seconds later. The retry therefore happens inside ExecStart, where the
      # first start blocks until the serve command itself succeeds (30 tries,
      # 2s apart, 60s ceiling). Restart= stays as the boot-time backstop:
      # `on-failure` is the only Restart= systemd permits for Type=oneshot, the
      # unit is never restarted on a clean exit, and StartLimitBurst bounds a
      # genuinely broken serve config rather than looping forever.
      startLimitBurst = 5;
      startLimitIntervalSec = 300;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 10;
        ExecStart = pkgs.writeShellScript "claudio-serve-start" ''
          set -u
          tries=30
          i=1
          while [ "$i" -le "$tries" ]; do
            if ${config.services.tailscale.package}/bin/tailscale serve \
              --bg --yes --https=443 --set-path=/claudio 127.0.0.1:8787; then
              exit 0
            fi
            echo "tailscale serve attempt $i/$tries failed (backend likely still NoState); retrying in 2s" >&2
            sleep 2
            i=$((i + 1))
          done
          echo "tailscale serve did not succeed within 60s" >&2
          exit 1
        '';
        # `-` prefix: don't fail the stop if the toggle syntax is rejected.
        # Targets only this path, so any unrelated serve config (srv also
        # serves /incidents/) is left untouched.
        ExecStop = "-${config.services.tailscale.package}/bin/tailscale serve --https=443 --set-path=/claudio off";
      };
    };
  };
}
