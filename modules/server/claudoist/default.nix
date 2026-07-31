{
  lib,
  pkgs,
  config,
  globals,
  inputs,
  ...
}:
# claudoist -- the srv side of the Todoist task-level UI Extension. See
# server.incidentInvestigator's own module comment for the shared opRunExec /
# claude-subscription-auth pattern this mirrors; the differences here are the
# request source (Todoist's HMAC-signed webhook, not a Grafana bearer secret)
# and the write target (a Todoist comment via `td`, not an incident bundle).
#
# The receiver itself (TypeScript) is built by the claudoist flake, not
# vendored into this tree -- see `inputs.claudoist` in nixerator's flake.nix.
# Only actions/*.sh run from the cloned repo path, the same split
# server.incidentInvestigator already uses for its own scripts.
#
# Trigger path (all on srv):
#   Todoist UI Extension button -> cloudflared tunnel (claudoist.srvrs.co)
#     -> claudoist receiver (this service, localhost:<port>, checks the
#        x-todoist-hmac-sha256 header)
#     -> actions/<name>.sh (scoped read-only `claude -p`)
#     -> `td comment add` on the task + Pushover notify.
#
# Secrets: VERIFICATION_TOKEN/PUSHOVER_* are op:// refs resolved at runtime by
# `op run` (see opRunExec below, identical to incident-investigator's).
# TODOIST_API_TOKEN is not an op:// ref -- it reuses the rendered secrets file
# render-secrets already produces on srv (the same .todoist_token field
# fish/`td` already read from at modules/apps/cli/fish/default.nix), read
# directly by startScript below.
let
  cfg = config.server.claudoist;
  homeDir = globals.user.homeDirectory;
  system = pkgs.stdenv.hostPlatform.system;

  receiverPkg = inputs.claudoist.packages.${system}.default;
  actionsDir = "${cfg.repoDir}/actions";

  runtimePath = lib.makeBinPath [
    pkgs.bash
    pkgs.llm-agents.claude-code
    pkgs.todoist-cli
    pkgs._1password-cli
    pkgs.jq
    pkgs.curl
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.findutils
    pkgs.gh
    pkgs.cacert
  ];

  tokenFile = "${homeDir}/.config/op/service-account-token";
  opRunExec =
    command:
    pkgs.writeShellScript "claudoist-op-run" ''
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

  # Same rendered-secrets file fish/`td` already read TODOIST_API_TOKEN from.
  secretsFile = "${homeDir}/.config/nixos-secrets/secrets.json";

  # Combined start wrapper for the receiver only (the cloudflared tunnel below
  # uses opRunExec directly, since it needs only the op:// TUNNEL_TOKEN).
  # Resolves TODOIST_API_TOKEN from the rendered secrets file, then execs
  # `op run` (which resolves VERIFICATION_TOKEN/PUSHOVER_* from Environment=
  # below) around the receiver binary. op run passes through any env value
  # that isn't an op:// ref unchanged, so TODOIST_API_TOKEN reaches the
  # receiver's actions/*.sh children as a literal value, not re-resolved.
  startScript = pkgs.writeShellScript "claudoist-start" ''
    set -eu
    if [ ! -r "${tokenFile}" ]; then
      echo "1Password service-account token not found at ${tokenFile}." >&2
      echo "Run 'just setup-op-token' on this host before enabling the service." >&2
      exit 1
    fi
    OP_SERVICE_ACCOUNT_TOKEN="$(${pkgs.coreutils}/bin/cat ${tokenFile})"
    export OP_SERVICE_ACCOUNT_TOKEN

    if [ ! -r "${secretsFile}" ]; then
      echo "Rendered secrets file not found at ${secretsFile}; run render-secrets first." >&2
      exit 1
    fi
    TODOIST_API_TOKEN="$(${pkgs.jq}/bin/jq -r '.todoist_token' ${secretsFile})"
    export TODOIST_API_TOKEN

    exec ${pkgs._1password-cli}/bin/op run -- ${receiverPkg}/bin/claudoist-receiver
  '';

  runtimeEnv = [
    "HOME=${homeDir}"
    "PATH=${runtimePath}"
    "PORT=${toString cfg.port}"
    "VERIFICATION_TOKEN=${cfg.verificationTokenRef}"
    "ACTIONS_DIR=${actionsDir}"
    "PUSHOVER_TOKEN=${cfg.pushoverTokenRef}"
    "PUSHOVER_USER=${cfg.pushoverUserRef}"
    "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
  ]
  ++ lib.optional (cfg.claudeModel != "") "CLAUDE_MODEL=${cfg.claudeModel}"
  ++ lib.optional (cfg.claudeTimeout != "") "CLAUDE_TIMEOUT=${cfg.claudeTimeout}";
in
{
  options.server.claudoist = {
    enable = lib.mkEnableOption "Todoist task-level UI Extension receiver (webhook + Claude Code actions)";

    repoDir = lib.mkOption {
      type = lib.types.str;
      default = "${homeDir}/git/claudoist";
      description = ''
        Path to the claudoist clone on this host. actions/*.sh are read from
        here; the receiver itself is installed as a package (see
        inputs.claudoist), not run from this clone. Must be checked out on
        srv before the service will start.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8100;
      description = ''
        Loopback port the receiver binds. cloudflared connects locally; no
        firewall port is opened, matching incident-investigator's posture.
      '';
    };

    verificationTokenRef = lib.mkOption {
      type = lib.types.str;
      default = "op://automation/claudoist/hmac-verification-token";
      description = ''
        1Password `op://` reference for the Todoist UI Extension verification
        token (from the App Management Console). Resolved at runtime via
        `op run`. Create the `automation/claudoist` item with this field
        before enabling.
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
      description = "Optional `claude --model` override for the action scripts. Empty means each script's own default.";
    };

    claudeTimeout = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "5m";
      description = "Optional CLAUDE_TIMEOUT override for the action scripts. Empty means each script's own default (5m).";
    };

    tunnel = {
      enable = lib.mkEnableOption "the cloudflared tunnel that fronts the receiver (claudoist.srvrs.co)";

      tokenRef = lib.mkOption {
        type = lib.types.str;
        default = "op://automation/claudoist/cloudflared-token";
        description = ''
          1Password `op://` reference for the cloudflared tunnel token (the
          "Get tunnel token" value from a remotely-managed / Config type
          Remote tunnel). Resolved at runtime via `op run` and passed to
          cloudflared as `TUNNEL_TOKEN`; the ingress rule
          (claudoist.srvrs.co -> http://localhost:<port>) lives in the
          Cloudflare dashboard, not here.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services = {
      claudoist = {
        description = "Todoist task-level UI Extension receiver";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          User = globals.user.name;
          Group = "users";
          ExecStart = "${startScript}";
          Environment = runtimeEnv;
          Restart = "on-failure";
          RestartSec = 10;
          # Same rationale as incident-investigator: this process shells out
          # to `claude` (Node) via actions/*.sh, which needs its own $HOME
          # for credentials, so ProtectHome/ProtectSystem stay off.
          NoNewPrivileges = true;
          LockPersonality = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
        };
      };

      cloudflared-claudoist = lib.mkIf cfg.tunnel.enable {
        description = "cloudflared tunnel (claudoist.srvrs.co) for the claudoist receiver";
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
  };
}
