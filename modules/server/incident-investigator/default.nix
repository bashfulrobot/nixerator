{
  lib,
  pkgs,
  config,
  globals,
  ...
}:
# incident-investigator -- the srv side of the homelab alert-investigation
# pipeline. A read-only Claude Code run investigates a firing darkstar Grafana
# alert and leaves a warm-start bundle for the human to resume; it never
# modifies the cluster. The pipeline code (receiver.py, investigate.sh,
# runbook.md) lives in the HOMELAB repo under `incident-investigator/`, not
# here -- this module only runs it as a service. See
# `<repoDir>/incident-investigator/README.md` for the full architecture.
#
# Trigger path (all on srv, outside darkstar, so it survives a cluster outage):
#   Grafana Cloud alert -> cloudflared tunnel (remediator.srvrs.co)
#     -> receiver.py (this service, localhost:8099, checks a shared secret)
#     -> investigate.sh (read-only `claude -p`, per runbook.md)
#     -> ~/incidents/<ts>-<fp>/rca.md + Pushover "RCA ready".
#
# Secrets: resolved at RUNTIME by `op run`, never rendered into the Nix store.
# `op run` needs OP_SERVICE_ACCOUNT_TOKEN in its environment (it does NOT read
# the on-disk token file on its own), and a systemd service doesn't inherit the
# login shell's export -- so the opRunExec wrapper loads the host SA token from
# ~/.config/op/service-account-token (installed by `just setup-op-token`) before
# exec'ing `op run`. `claude` picks up the user's subscription credentials at
# ~/.claude. No API key or nixos-secrets entry is needed by this module.
#
# The subscription path needs a one-time `claude` login on srv so
# ~/.claude/.credentials.json exists. After that an idle box is fine: the file
# also holds a long-lived refresh token, and the service (running as the user
# with its own $HOME, no ProtectHome) refreshes an expired access token from it
# and writes the new one back, no interactive session required.
let
  cfg = config.server.incidentInvestigator;
  homeDir = globals.user.homeDirectory;

  # Everything the receiver and the investigator shell out to. `claude`
  # authenticates via ~/.claude (HOME is set below); kubectl/flux read the
  # read-only darkstar kubeconfig; op resolves the op:// refs at runtime.
  runtimePath = lib.makeBinPath [
    pkgs.python3
    pkgs.llm-agents.claude-code
    pkgs.kubectl
    pkgs.fluxcd
    pkgs._1password-cli
    pkgs.jq
    pkgs.curl
    pkgs.git
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.findutils
    pkgs.cacert
  ];

  scriptsDir = "${cfg.repoDir}/incident-investigator";

  # `op run` authenticates as a service account only when OP_SERVICE_ACCOUNT_TOKEN
  # is in its environment -- it does NOT auto-detect the on-disk token file. A
  # systemd service doesn't inherit the login shell's export (that lives in the
  # fish config), so without this it dies with "No accounts configured for use
  # with 1Password CLI". This wrapper loads the host SA token from the file
  # `just setup-op-token` installs, exports it, then execs `op run`. The token
  # stays in the process environment only -- never the Nix store, never argv.
  tokenFile = "${homeDir}/.config/op/service-account-token";
  opRunExec =
    command:
    pkgs.writeShellScript "incident-investigator-op-run" ''
      set -eu
      if [ ! -r "${tokenFile}" ]; then
        echo "1Password service-account token not found at ${tokenFile}." >&2
        echo "Run 'just setup-op-token' on this host before enabling the service." >&2
        exit 1
      fi
      OP_SERVICE_ACCOUNT_TOKEN="$(${pkgs.coreutils}/bin/cat ${tokenFile})"
      export OP_SERVICE_ACCOUNT_TOKEN
      exec ${pkgs._1password-cli}/bin/op run -- ${command}
    '';

  # op run resolves every op:// value in the child env, so receiver.py and the
  # investigate.sh children it spawns all see the real secret. Refs that are
  # empty (e.g. an unset model) are simply omitted.
  runtimeEnv = [
    "HOME=${homeDir}"
    "PATH=${runtimePath}"
    "LISTEN_ADDR=${cfg.listenAddr}"
    "INVESTIGATE_SH=${scriptsDir}/investigate.sh"
    "REPO_DIR=${cfg.repoDir}"
    "KUBECONFIG=${cfg.kubeconfig}"
    "OUT_ROOT=${cfg.outRoot}"
    "STATE_DIR=${cfg.stateDir}"
    "SUPPRESS_SECONDS=${toString cfg.suppressSeconds}"
    "SHARED_SECRET=${cfg.sharedSecretRef}"
    "PUSHOVER_TOKEN=${cfg.pushoverTokenRef}"
    "PUSHOVER_USER=${cfg.pushoverUserRef}"
    "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
  ]
  ++ lib.optional (cfg.claudeModel != "") "CLAUDE_MODEL=${cfg.claudeModel}";
in
{
  options.server.incidentInvestigator = {
    enable = lib.mkEnableOption "read-only Claude Code darkstar alert investigator (webhook receiver)";

    repoDir = lib.mkOption {
      type = lib.types.str;
      default = "${homeDir}/git/homelab";
      description = ''
        Path to the homelab clone on this host. The pipeline scripts are read
        from `<repoDir>/incident-investigator/`, and the same path is passed to
        `claude` as the read-only desired-state context. Must be checked out on
        srv before the service will start.
      '';
    };

    kubeconfig = lib.mkOption {
      type = lib.types.str;
      default = "${homeDir}/.kube/darkstar-ro";
      description = ''
        Kubeconfig the investigator uses. Point this at a READ-ONLY
        (`view`-bound ServiceAccount) kubeconfig for darkstar -- RBAC is the
        backstop behind investigate.sh's own read-only tool allowlist.
      '';
    };

    listenAddr = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:8099";
      description = ''
        Address receiver.py binds. Keep it on loopback: cloudflared connects
        locally, and the endpoint launches Claude with cluster credentials, so
        it must never be exposed directly. No firewall port is opened.
      '';
    };

    outRoot = lib.mkOption {
      type = lib.types.str;
      default = "${homeDir}/incidents";
      description = "Directory where incident bundles (rca.md + evidence) are written.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "${homeDir}/.incident-investigator";
      description = "Dedup/suppression state directory.";
    };

    suppressSeconds = lib.mkOption {
      type = lib.types.int;
      default = 1800;
      description = "Re-investigate the same workload fingerprint no more often than this.";
    };

    sharedSecretRef = lib.mkOption {
      type = lib.types.str;
      default = "op://automation/incident-investigator/shared-secret";
      description = ''
        1Password `op://` reference for the bearer token receiver.py checks on
        every webhook POST. Resolved at runtime via `op run`; the same value
        goes in the Grafana webhook contact point's Authorization header.
        Create the `automation/incident-investigator` item with a
        `shared-secret` field before enabling.
      '';
    };

    pushoverTokenRef = lib.mkOption {
      type = lib.types.str;
      default = "op://automation/Pushover-api/api-token";
      description = "1Password `op://` reference for the Pushover application token (reuses the existing Pushover-api item).";
    };

    pushoverUserRef = lib.mkOption {
      type = lib.types.str;
      default = "op://automation/Pushover-api/user-key";
      description = "1Password `op://` reference for the Pushover user key.";
    };

    claudeModel = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "claude-opus-4-8";
      description = "Optional `claude --model` override. Empty means the CLI default.";
    };

    tunnel = {
      enable = lib.mkEnableOption "the cloudflared tunnel that fronts the receiver (remediator.srvrs.co)";

      tokenRef = lib.mkOption {
        type = lib.types.str;
        default = "op://automation/incident-investigator/cloudflared-token";
        description = ''
          1Password `op://` reference for the cloudflared tunnel token (the
          "Get tunnel token" value from a remotely-managed / Config type
          Remote tunnel). Resolved at runtime via `op run` and passed to
          cloudflared as `TUNNEL_TOKEN`; the ingress rules live in the
          Cloudflare dashboard, not here. Distinct from `sharedSecretRef`.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.incident-investigator = {
      description = "Read-only Claude Code darkstar alert investigator (webhook receiver)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = globals.user.name;
        Group = "users";
        # opRunExec loads the host SA token from ~/.config/op/service-account-token
        # into OP_SERVICE_ACCOUNT_TOKEN, then `op run` resolves the op:// refs in
        # the env and execs receiver.py with the real values in its environment;
        # the investigate.sh children it spawns inherit them. Nothing secret is
        # written to disk or the Nix store.
        ExecStart = opRunExec "${pkgs.python3}/bin/python3 ${scriptsDir}/receiver.py";
        Environment = runtimeEnv;
        Restart = "on-failure";
        RestartSec = 10;
        # Light hardening only. The process shells out to `claude` (Node), which
        # breaks under SystemCallFilter / MemoryDenyWriteExecute, and it needs
        # its own $HOME for credentials -- so ProtectHome/ProtectSystem stay off.
        # The real containment is investigate.sh's read-only tool allowlist plus
        # the view-only kubeconfig; this service is loopback-only.
        NoNewPrivileges = true;
        LockPersonality = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
      };
    };

    # The Cloudflare tunnel that reaches the receiver. Your tunnel is
    # remotely-managed (Config type: Remote), so cloudflared runs with a token
    # and pulls its ingress (remediator.srvrs.co -> http://localhost:8099) from
    # the dashboard. The native services.cloudflared module is credentials-file
    # only and can't drive a token tunnel, hence this small service. Runs as the
    # user so `op run` finds the host SA token to resolve TUNNEL_TOKEN.
    systemd.services.cloudflared-remediator = lib.mkIf cfg.tunnel.enable {
      description = "cloudflared tunnel (remediator.srvrs.co) for the incident-investigator receiver";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = globals.user.name;
        Group = "users";
        Environment = [
          "HOME=${homeDir}"
          "PATH=${
            lib.makeBinPath [
              pkgs.cloudflared
              pkgs._1password-cli
            ]
          }"
          "TUNNEL_TOKEN=${cfg.tunnel.tokenRef}"
        ];
        ExecStart = opRunExec "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run";
        Restart = "on-failure";
        RestartSec = 10;
        NoNewPrivileges = true;
        LockPersonality = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
      };
    };
  };
}
