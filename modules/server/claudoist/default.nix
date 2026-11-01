{
  lib,
  pkgs,
  config,
  globals,
  inputs,
  secretsLib,
  ...
}:
# claudoist -- the srv side of the Todoist task-level UI Extension. It only
# answers Todoist's HMAC-signed POST /process with a card whose buttons open
# the claudoist helper's loopback URL on the laptop (apps.cli.claudoist-helper
# on qbert, a launchd agent on the Mac). The receiver runs nothing itself: no
# `claude`, no `td`, no Pushover. See docs/spec.md in the claudoist repo.
#
# The receiver (TypeScript) is built by the claudoist flake, not vendored into
# this tree -- see `inputs.claudoist` in nixerator's flake.nix.
#
# Trigger path:
#   Todoist UI Extension button -> cloudflared tunnel (claudoist.srvrs.co)
#     -> claudoist receiver (this service, localhost:<port>, checks the
#        x-todoist-hmac-sha256 header)
#     -> card with http://127.0.0.1:47615/launch?... buttons
#     -> the helper on the laptop opens kitty running claude.
#
# Secrets: VERIFICATION_TOKEN and HELPER_TOKEN are op:// refs resolved at
# runtime by the gopass runner (lib/secrets.nix gopassRun). HELPER_TOKEN is the
# same value the helper reads on each laptop. It ends up in card URLs, which
# Todoist's servers see (claudoist issue 24 tracks signed links).
let
  cfg = config.server.claudoist;
  homeDir = globals.user.homeDirectory;
  inherit (pkgs.stdenv.hostPlatform) system;

  receiverPkg = inputs.claudoist.packages.${system}.default;

  # Resolves every op:// value in the child env from the secauto gopass store, then
  # execs the command. Replaces `op run` and the 1Password service-account token.
  opRunExec =
    command:
    pkgs.writeShellScript "claudoist-gopass-run" ''
      exec ${secretsLib.gopassRun { inherit pkgs; }} ${command}
    '';

  runtimeEnv = [
    "HOME=${homeDir}"
    "PORT=${toString cfg.port}"
    "HOST=127.0.0.1"
    "VERIFICATION_TOKEN=${cfg.verificationTokenRef}"
    "HELPER_TOKEN=${cfg.helperTokenRef}"
    "HELPER_BASE_URL=${cfg.helperBaseUrl}"
    "CARD_MODE=${cfg.cardMode}"
  ];
in
{
  options.server.claudoist = {
    enable = lib.mkEnableOption "Todoist task-level UI Extension receiver (returns launch cards for the local helper)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8100;
      description = ''
        Loopback port the receiver binds. cloudflared connects locally; no
        firewall port is opened, matching incident-investigator's posture.
      '';
    };

    helperTokenRef = lib.mkOption {
      type = lib.types.str;
      default = "op://automation/claudoist/helper-token";
      description = ''
        gopass reference (op:// form, see lib/secrets.nix gopassRun) for the
        shared secret the helper checks on /launch. The receiver puts it in the
        card URLs. Same entry the helper reads on each laptop.
      '';
    };

    helperBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:47615";
      description = "Where the helper listens on the laptop. Card buttons open this URL in the browser.";
    };

    cardMode = lib.mkOption {
      type = lib.types.enum [
        "url"
        "clipboard"
      ];
      default = "url";
      description = ''
        `url` makes card buttons open the helper link. `clipboard` makes them
        copy the claude command instead and keeps the helper token out of the
        card, for when Todoist refuses localhost links (claudoist issue 14).
      '';
    };

    verificationTokenRef = lib.mkOption {
      type = lib.types.str;
      default = "op://automation/claudoist/hmac-verification-token";
      description = ''
        1Password `op://` reference for the Todoist UI Extension verification
        token (from the App Management Console). Resolved at runtime via
        the gopass runner (lib/secrets.nix gopassRun). Create the `automation/claudoist` item with this field
        before enabling.
      '';
    };

    tunnel = {
      enable = lib.mkEnableOption "the cloudflared tunnel that fronts the receiver (claudoist.srvrs.co)";

      tokenRef = lib.mkOption {
        type = lib.types.str;
        default = "op://automation/claudoist/cloudflared-token";
        description = ''
          1Password `op://` reference for the cloudflared tunnel token (the
          "Get tunnel token" value from a remotely-managed / Config type
          Remote tunnel). Resolved at runtime via the gopass runner (lib/secrets.nix gopassRun) and passed to
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
          ExecStart = opRunExec "${receiverPkg}/bin/claudoist-receiver";
          Environment = runtimeEnv;
          Restart = "on-failure";
          RestartSec = 10;
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
