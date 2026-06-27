{
  config,
  lib,
  pkgs,
  globals,
  ...
}:
# noclaw -- always-on Claude Code Remote Control endpoint, isolated in a
# declarative systemd-nspawn container.
#
# Design (see noclaw repo docs/superpowers/specs/2026-06-27-... for the full
# rationale and the spike that validated RC-under-nspawn):
#   * The endpoint runs INSIDE a NixOS container, not on the host. The repo is
#     bind-mounted READ-ONLY, so the runtime physically cannot modify its own
#     programs or guardrail; only /data is writable. No host home, no secrets.
#   * Authoring happens on the HOST (writable repo) gated by the out-of-band
#     NOCLAW_EDIT flag; the container never has it.
#   * RC needs three cred bits (validated 2026-06-27): ~/.claude/.credentials.json
#     (token), ~/.claude.json (account/org), and a seeded workspace-trust flag
#     for the working dir. We bind-mount the first two READ-ONLY and work on
#     COPIES in a writable container HOME -- the host's live creds are never
#     written by the container.
#   * Egress is masqueraded out the host WAN iface. qbert already pins the
#     singleton networking.nat.externalInterface to enp34s0 (libvirt), so we add
#     our own POSTROUTING masquerade for the container subnet rather than
#     redefining it.
#   * Recycle timer lives inside the container; autoStart + reboot survival come
#     from the declarative container itself (no user-linger needed).
let
  cfg = config.server.noclaw;

  user = globals.user.name;
  homeDir = globals.user.homeDirectory;

  claudePkg = pkgs.llm-agents.claude-code;

  subnet = "10.231.136.0/24";
  hostAddr = "10.231.136.1";
  localAddr = "10.231.136.2";

  # Tools available inside the container to the harness and to bin/ programs.
  # bin/ programs may use these host-level tools internally; the gate hook still
  # confines the agent to clean ./bin/* invocations.
  containerTools = [
    claudePkg
    pkgs.git
    pkgs.coreutils
    pkgs.bash
    pkgs.gnugrep
    pkgs.gnused
    pkgs.findutils
    pkgs.jq
    pkgs.curl
    pkgs.nettools
    pkgs.util-linux
    pkgs._1password-cli
    pkgs.cacert
  ];

  # Runs as root (ExecStartPre with "+"): the host creds are mode 0600 owned by
  # uid 1000, unreadable by the container's unprivileged noclaw user. Root stages
  # COPIES into the noclaw-owned HOME and chowns them; the host's live creds are
  # never written by the container.
  stageScript = pkgs.writeShellScript "noclaw-rc-stage" ''
    set -euo pipefail
    install -d -m 0700 -o noclaw -g noclaw /var/lib/noclaw/.claude
    cp -f /creds/.credentials.json /var/lib/noclaw/.claude/.credentials.json
    cp -f /creds-account.json /var/lib/noclaw/.claude.json
    # Seed workspace trust for the read-only repo working dir.
    tmp="$(mktemp /var/lib/noclaw/.claude.json.XXXXXX)"
    ${pkgs.jq}/bin/jq '.projects["/repo"].hasTrustDialogAccepted = true' \
      /var/lib/noclaw/.claude.json > "$tmp" && mv "$tmp" /var/lib/noclaw/.claude.json
    chown -R noclaw:noclaw /var/lib/noclaw
    chmod 0600 /var/lib/noclaw/.claude/.credentials.json /var/lib/noclaw/.claude.json
  '';

  runScript = pkgs.writeShellScript "noclaw-rc-start" ''
    set -euo pipefail
    export HOME=/var/lib/noclaw
    cd /repo
    exec ${claudePkg}/bin/claude remote-control --name noclaw --spawn session
  '';
in
{
  options.server.noclaw = {
    enable = lib.mkEnableOption "always-on contained Claude Code Remote Control endpoint (noclaw)";

    wanInterface = lib.mkOption {
      type = lib.types.str;
      default = "wlo1";
      example = "enp34s0";
      description = "Host WAN interface the container's egress is masqueraded out of.";
    };

    opTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/noclaw-op-token.env";
      description = ''
        Host path to a rendered file containing `OP_SERVICE_ACCOUNT_TOKEN=...`
        for secret-using bin/ tasks (consumed via `op run`/`op inject`). Point
        this at a least-privilege 1Password service-account token rendered by the
        nixos-secrets pipeline. The file is bind-mounted read-only and read by
        systemd (as root) before dropping to the unprivileged container user, so
        the value never lands in a world-readable place. When null (default), no
        1Password token is available inside the container.
      '';
    };

    recycle = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Periodically restart the in-container session to flush context.";
      };
      onCalendar = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 04:00:00";
        example = "Mon *-*-* 04:00:00";
        description = "systemd OnCalendar expression for the periodic context-flush restart.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Container egress: add the veth to the NAT forward set (qbert already sets
    # the singleton externalInterface to enp34s0), and masquerade the container
    # subnet out the actual WAN iface.
    networking.nat.internalInterfaces = [ "ve-noclaw" ];
    networking.firewall.extraCommands = lib.mkAfter ''
      iptables -t nat -C POSTROUTING -s ${subnet} -o ${cfg.wanInterface} -j MASQUERADE 2>/dev/null \
        || iptables -t nat -A POSTROUTING -s ${subnet} -o ${cfg.wanInterface} -j MASQUERADE
    '';

    # Writable scratch volume for the container's runtime output.
    systemd.tmpfiles.rules = [ "d /var/lib/noclaw-data 0750 root root -" ];

    containers.noclaw = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = hostAddr;
      localAddress = localAddr;

      bindMounts = {
        "/repo" = {
          hostPath = "${homeDir}/git/noclaw";
          isReadOnly = true;
        };
        "/data" = {
          hostPath = "/var/lib/noclaw-data";
          isReadOnly = false;
        };
        "/creds" = {
          hostPath = "${homeDir}/.claude";
          isReadOnly = true;
        };
        "/creds-account.json" = {
          hostPath = "${homeDir}/.claude.json";
          isReadOnly = true;
        };
      }
      // lib.optionalAttrs (cfg.opTokenFile != null) {
        "/run/noclaw-op.env" = {
          hostPath = toString cfg.opTokenFile;
          isReadOnly = true;
        };
      };

      config =
        { lib, ... }:
        lib.mkMerge [
          {
            system.stateVersion = "25.11";
            networking.firewall.enable = false;
            networking.nameservers = [
              "1.1.1.1"
              "9.9.9.9"
            ];
            environment.systemPackages = containerTools;

            users.users.noclaw = {
              isSystemUser = true;
              group = "noclaw";
              home = "/var/lib/noclaw";
              # script(1) execs the account's login shell; a system user defaults
              # to nologin ("account is currently not available"), so give it bash.
              shell = pkgs.bashInteractive;
            };
            users.groups.noclaw = { };

            systemd.services.noclaw = {
              description = "noclaw Remote Control endpoint (contained)";
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];
              serviceConfig = {
                Type = "simple";
                User = "noclaw";
                Group = "noclaw";
                StateDirectory = "noclaw";
                # Optional 1Password service-account token for secret-using tasks;
                # read by systemd as root, absent unless opTokenFile is set. The
                # "-" tolerates the file briefly missing during boot.
                EnvironmentFile = lib.mkIf (cfg.opTokenFile != null) "-/run/noclaw-op.env";
                ExecStartPre = "+${stageScript}";
                ExecStart = "${pkgs.util-linux}/bin/script -q -f -c ${runScript} /dev/null";
                Restart = "always";
                RestartSec = "15";
                Environment = [
                  "PATH=${lib.makeBinPath containerTools}"
                  "HOME=/var/lib/noclaw"
                  "SHELL=${pkgs.bashInteractive}/bin/bash"
                ];
                # Defense in depth atop the container boundary. Kept Node-safe
                # (no MemoryDenyWriteExecute / SystemCallFilter that breaks the
                # JIT); the nspawn namespaces are the primary wall.
                NoNewPrivileges = true;
                CapabilityBoundingSet = "";
                AmbientCapabilities = "";
                RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX";
                RestrictNamespaces = true;
                LockPersonality = true;
                ProtectKernelTunables = true;
                ProtectKernelModules = true;
                ProtectControlGroups = true;
                ProtectHostname = true;
                PrivateTmp = true;
              };
            };
          }
          (lib.mkIf cfg.recycle.enable {
            systemd.services.noclaw-recycle = {
              description = "Flush noclaw context by restarting the session";
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${pkgs.systemd}/bin/systemctl restart noclaw.service";
              };
            };
            systemd.timers.noclaw-recycle = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = cfg.recycle.onCalendar;
                Persistent = true;
              };
            };
          })
        ];
    };
  };
}
