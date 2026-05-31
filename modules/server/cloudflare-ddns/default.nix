{
  lib,
  config,
  secrets,
  ...
}:
let
  cfg = config.server.cloudflareDdns;

  hasToken =
    secrets ? cloudflareDdns
    && secrets.cloudflareDdns ? apiToken
    && secrets.cloudflareDdns.apiToken != "";

  joinCsv = items: lib.concatStringsSep "," items;

  # Only emit DOMAINS / IP4_DOMAINS / IP6_DOMAINS when the corresponding list
  # is non-empty. An empty env var would be passed through to the container
  # and ambiguously parsed by upstream.
  domainEnv =
    lib.optionalAttrs (cfg.domains != [ ]) { DOMAINS = joinCsv cfg.domains; }
    // lib.optionalAttrs (cfg.ip4Domains != [ ]) { IP4_DOMAINS = joinCsv cfg.ip4Domains; }
    // lib.optionalAttrs (cfg.ip6Domains != [ ]) { IP6_DOMAINS = joinCsv cfg.ip6Domains; };
in
{
  options.server.cloudflareDdns = {
    enable = lib.mkEnableOption "timothymiller/cloudflare-ddns dynamic DNS updater";

    image = lib.mkOption {
      type = lib.types.str;
      # Digest-pinned to docker.io/timothyjmiller/cloudflare-ddns:latest as of
      # 2026-05-18 (tag 2.1.2). Bump by:
      #   curl -sS https://hub.docker.com/v2/repositories/timothyjmiller/cloudflare-ddns/tags/ \
      #     | jq -r '.results[0] | "\(.name)  \(.digest // .images[0].digest)"'
      # and updating this default to the new digest.
      default = "docker.io/timothyjmiller/cloudflare-ddns@sha256:37c99677e997710c1bbe9d74c93f2e3b8de3457a5ca6e28643e251b38ed05311";
      description = ''
        OCI image to run. Defaults to a digest-pinned reference of the
        upstream image. Bump the digest deliberately; a floating `:latest`
        would let a compromised upstream silently push code that runs
        with the Cloudflare API token in env.
      '';
    };

    domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "example.com"
        "www.example.com"
      ];
      description = ''
        Domains to update for both IPv4 and IPv6 (`DOMAINS` env var).
        At least one of `domains`, `ip4Domains`, or `ip6Domains` must be set.
      '';
    };

    ip4Domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Domains to update for IPv4 only (`IP4_DOMAINS` env var).";
    };

    ip6Domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Domains to update for IPv6 only (`IP6_DOMAINS` env var).";
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "host";
      example = "bridge";
      description = ''
        Docker network mode. Upstream documents that `host` is required for
        IPv6 detection because the container reads the host's routing table.
        Override to `bridge` only if IPv6 is disabled via `ip6Provider = "none"`;
        an assertion below enforces that pairing.
      '';
    };

    ip4Provider = lib.mkOption {
      type = lib.types.str;
      default = "ipify";
      example = "cloudflare.trace";
      description = ''
        Source for the host's public IPv4 (`IP4_PROVIDER` env var). Defaults
        to the upstream default. Set to `"none"` to disable IPv4 updates.
      '';
    };

    ip6Provider = lib.mkOption {
      type = lib.types.str;
      default = "cloudflare.trace";
      example = "none";
      description = ''
        Source for the host's public IPv6 (`IP6_PROVIDER` env var). Defaults
        to the upstream default. Set to `"none"` to disable IPv6 updates;
        required if `network` is not `"host"`.
      '';
    };

    updateCron = lib.mkOption {
      type = lib.types.str;
      default = "@every 5m";
      example = "@every 1h";
      description = ''
        Update schedule (`UPDATE_CRON` env var). Accepts cron expressions
        and `@every <duration>` shortcuts. Default matches upstream.
      '';
    };

    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        SHOUTRRR = "discord://token@id";
        HEALTHCHECKS = "https://hc-ping.com/abc-123";
      };
      description = ''
        Additional environment variables passed verbatim into the container.
        See upstream README for the full list (WAF_LISTS, SHOUTRRR,
        HEALTHCHECKS, TTL, PROXIED, etc.).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.docker.enable;
        message = ''
          server.cloudflareDdns.enable = true requires
          virtualisation.docker.enable = true. Enable apps.cli.docker on
          this host (or set the Docker option directly).
        '';
      }
      {
        assertion = hasToken;
        message = ''
          server.cloudflareDdns.enable = true requires
          secrets.cloudflareDdns.apiToken to be set. Add the
          `cloudflareDdns.apiToken` entry to secrets.json.tpl and run
          `just render-secrets`.
        '';
      }
      {
        assertion = cfg.domains != [ ] || cfg.ip4Domains != [ ] || cfg.ip6Domains != [ ];
        message = ''
          server.cloudflareDdns.enable = true requires at least one of
          `domains`, `ip4Domains`, or `ip6Domains` to be non-empty.
        '';
      }
      {
        assertion = cfg.network == "host" || cfg.ip6Provider == "none";
        message = ''
          server.cloudflareDdns.network must be "host" whenever
          server.cloudflareDdns.ip6Provider is anything other than "none".
          Upstream reads the host routing table for IPv6 detection and only
          works with host networking.
        '';
      }
    ];

    virtualisation.oci-containers.containers."cloudflare-ddns" = {
      inherit (cfg) image;
      autoStart = true;
      extraOptions = [ "--network=${cfg.network}" ];
      environment = {
        CLOUDFLARE_API_TOKEN = secrets.cloudflareDdns.apiToken;
        IP4_PROVIDER = cfg.ip4Provider;
        IP6_PROVIDER = cfg.ip6Provider;
        UPDATE_CRON = cfg.updateCron;
      }
      // domainEnv
      // cfg.extraEnv;
    };
  };
}
