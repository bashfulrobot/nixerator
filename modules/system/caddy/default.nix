{
  lib,
  pkgs,
  config,
  secrets,
  ...
}:

let
  cfg = config.system.caddy;

  caddyWithTailscale = pkgs.caddy.withPlugins {
    plugins = [
      "github.com/tailscale/caddy-tailscale@v0.0.0-20260106222316-bb080c4414ac"
    ];
    hash = "sha256-xJOPVE56h4tlhW7m8ZFN8F2jrZW/3gYeLXVqaEaoVvY=";
  };
in
{
  options.system.caddy = {
    enable = lib.mkEnableOption "system Caddy with caddy-tailscale plugin";

    tailnetDomain = lib.mkOption {
      type = lib.types.str;
      default = "goat-cloud.ts.net";
      description = "Tailnet MagicDNS domain suffix (e.g. goat-cloud.ts.net).";
    };

    tsnetNodes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Names of in-process tsnet nodes Caddy should join the tailnet as.
        Each becomes its own tailnet identity at <name>.<tailnetDomain>
        with its own Let's Encrypt cert via Tailscale HTTPS.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      package = caddyWithTailscale;
      email = "caddy@localhost";

      globalConfig = lib.optionalString (cfg.tsnetNodes != [ ]) ''
        tailscale {
          auth_key {env.TS_AUTHKEY}
          state_dir /var/lib/caddy/tsnet
          ${lib.concatMapStrings (n: ''
            ${n} {
              hostname ${n}
              ephemeral false
            }
          '') cfg.tsnetNodes}
        }
      '';
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/caddy/tsnet 0750 caddy caddy -"
    ];

    # SECURITY-FOLLOWUP: this writes TS_AUTHKEY into the systemd unit file
    # under /nix/store, which is world-readable. Acceptable today because the
    # only local user is `dustin`, but every Claude Code MCP child (npx-spawned)
    # also runs as `dustin` and could exfiltrate the key on disk. Migrate to
    # sops-nix / agenix so the key is decrypted at activation time into
    # /run/secrets/ and loaded via systemd `EnvironmentFile=` or
    # `LoadCredential=`. Tracked separately from issue #43.
    systemd.services.caddy.serviceConfig.Environment = lib.optionals (
      secrets ? tailscale && secrets.tailscale ? caddyAuthKey
    ) [ "TS_AUTHKEY=${secrets.tailscale.caddyAuthKey}" ];
  };
}
