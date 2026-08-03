{
  lib,
  pkgs,
  config,
  secrets,
  secretsLib,
  globals,
  ...
}:
let
  cfg = config.server.cloudflareDdns;

  # Presence-only guard: never reads the token value, only whether the key
  # exists. The value is materialised at activation from the off-store secrets
  # file (issue #265), so it must not be read at eval.
  hasToken = secrets ? cloudflareDdns && secrets.cloudflareDdns ? apiToken;

  joinCsv = items: lib.concatStringsSep "," items;

  # Token-file paths. The host file is materialised through
  # `environment.etc` at activation time so the value never enters
  # `docker run` argv (which would otherwise expose it in
  # /proc/<pid>/cmdline) and never lands in a world-readable file under
  # /etc/tmpfiles.d. `environment.etc` rewrites the file on every
  # activation, so a rotated 1Password value propagates on the next
  # `nixos-rebuild switch` without any manual cleanup. The container
  # sees the file via a read-only bind mount; CLOUDFLARE_API_TOKEN_FILE
  # in env tells upstream to read it (the documented "Docker secrets
  # compatible" path).
  hostTokenPath = "/etc/cloudflare-ddns/token";
  containerTokenPath = "/run/secrets/cloudflare-ddns-token";

  # Env keys the module owns. Passing any of these via `extraEnv` would
  # silently override the typed options below (including the API token).
  # We strip them from `extraEnv` and surface a warning so a config that
  # tries to set them is loud rather than silent.
  reservedEnvKeys = [
    "CLOUDFLARE_API_TOKEN"
    "CLOUDFLARE_API_TOKEN_FILE"
    "DOMAINS"
    "IP4_DOMAINS"
    "IP6_DOMAINS"
    "WAF_LISTS"
    "IP4_PROVIDER"
    "IP6_PROVIDER"
    "UPDATE_CRON"
  ];

  conflictingExtraKeys = lib.intersectLists reservedEnvKeys (lib.attrNames cfg.extraEnv);
  sanitizedExtraEnv = removeAttrs cfg.extraEnv reservedEnvKeys;

  # Only emit DOMAINS / IP4_DOMAINS / IP6_DOMAINS / WAF_LISTS when the
  # corresponding list is non-empty. An empty env var would be passed
  # through to the container and ambiguously parsed by upstream.
  domainEnv =
    lib.optionalAttrs (cfg.domains != [ ]) { DOMAINS = joinCsv cfg.domains; }
    // lib.optionalAttrs (cfg.ip4Domains != [ ]) { IP4_DOMAINS = joinCsv cfg.ip4Domains; }
    // lib.optionalAttrs (cfg.ip6Domains != [ ]) { IP6_DOMAINS = joinCsv cfg.ip6Domains; }
    // lib.optionalAttrs (cfg.wafLists != [ ]) { WAF_LISTS = joinCsv cfg.wafLists; };
in
{
  options.server.cloudflareDdns = {
    enable = lib.mkEnableOption "timothymiller/cloudflare-ddns dynamic DNS updater";

    image = lib.mkOption {
      type = lib.types.str;
      # Digest-pinned to docker.io/timothyjmiller/cloudflare-ddns 2.1.2 as of
      # 2026-05-18. Bump to a real semver tag, not `:latest`, so the pin
      # narrative stays meaningful:
      #   curl -sS https://hub.docker.com/v2/repositories/timothyjmiller/cloudflare-ddns/tags/?page_size=20 \
      #     | jq -r '.results | map(select(.name | test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))) | .[0] | "\(.name)  \(.digest // .images[0].digest)"'
      # then update this default to the new digest. When bumping, also
      # re-check that the upstream binary has not added any inbound
      # listener (`docker run --rm <new-image> --help` or `ss -tlnp`
      # inside the container). `--network host` shares srv's interfaces,
      # so any new listener would be exposed on every interface without
      # firewall scoping.
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
        At least one of `domains`, `ip4Domains`, `ip6Domains`, or `wafLists`
        must be set.
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

    wafLists = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "abc123/my-blocklist" ];
      description = ''
        Cloudflare WAF lists to manage (`WAF_LISTS` env var). Each entry is
        `account-id/list-name`. Upstream treats WAF lists as an alternative
        to the domain options for satisfying the "at least one thing to
        update" requirement.
      '';
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "host";
      example = "bridge";
      description = ''
        Docker network mode. Upstream documents that `host` is required for
        IPv6 detection because the container reads the host's routing table.
        Override to `bridge` only if IPv6 is disabled via
        `ip6Provider = "none"`; an assertion below enforces that pairing.

        `host` networking on srv means the container shares every host
        interface (LAN, Tailscale, libvirt bridges) without per-interface
        firewall scoping. Today the upstream binary has no inbound
        listener, but the image-bump checklist above flags this so the
        assumption is re-verified on every upgrade.
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
        See upstream README for the full list (SHOUTRRR, HEALTHCHECKS, TTL,
        PROXIED, etc.). Keys the module manages directly (`DOMAINS`,
        `WAF_LISTS`, `CLOUDFLARE_API_TOKEN*`, `IP[46]_*`, `UPDATE_CRON`)
        are stripped from this attrset before merge so this option cannot
        override the typed options; a build-time warning fires when any
        reserved key appears here.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
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
              secrets.cloudflareDdns.apiToken to be set. Create the
              `nixerator/cloudflare-ddns` 1Password item (type: API Credential,
              field: `credential`, value: a Cloudflare API token scoped to
              `Zone / DNS / Edit` on the target zones) and run
              `just render-secrets`.
            '';
          }
          {
            assertion =
              cfg.domains != [ ] || cfg.ip4Domains != [ ] || cfg.ip6Domains != [ ] || cfg.wafLists != [ ];
            message = ''
              server.cloudflareDdns.enable = true requires at least one of
              `domains`, `ip4Domains`, `ip6Domains`, or `wafLists` to be
              non-empty.
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
          {
            # `domains` is a both-stack list upstream: every entry contributes
            # to the IPv6 update set, so an empty `ip6Domains` is not enough
            # to make ip6Provider = "none" safe.
            assertion = cfg.ip6Provider != "none" || (cfg.ip6Domains == [ ] && cfg.domains == [ ]);
            message = ''
              server.cloudflareDdns.ip6Provider is "none" but `domains` or
              `ip6Domains` is non-empty. Upstream treats both as IPv6 targets
              and silently skips AAAA updates in this combination. Either set
              ip6Provider to a real provider (e.g. "cloudflare.trace") or move
              both-stack entries into `ip4Domains`.
            '';
          }
        ];

        warnings = lib.optional (conflictingExtraKeys != [ ]) ''
          server.cloudflareDdns.extraEnv contains keys the module manages
          directly: ${lib.concatStringsSep ", " conflictingExtraKeys}. These
          are dropped from extraEnv. Set them via the typed options instead
          (or remove them).
        '';
      }

      # Everything below needs the token to exist, so guard the whole block
      # behind hasToken (presence only). The strict assertion above fires first
      # with an actionable message; without this guard, a host missing the key
      # would hit `attribute 'cloudflareDdns' missing` before the assertion
      # machinery could surface anything.
      (lib.mkIf hasToken {
        # Token file materialised at activation from the off-store secrets file
        # (0400, root), so the value never enters `docker run` argv and never
        # lands in the world-readable /nix/store (issue #265). The container
        # mounts this path read-only. jq reads the value straight from the
        # secrets file, so it never passes through argv either.
        system.activationScripts.cloudflareDdnsToken = lib.stringAfter [ "etc" ] (
          secretsLib.installValue {
            jq = "${pkgs.jq}/bin/jq";
            secretsFile = secretsLib.file globals;
            path = ".cloudflareDdns.apiToken";
            dest = hostTokenPath;
            mode = "0400";
          }
        );

        virtualisation.oci-containers.containers."cloudflare-ddns" = {
          inherit (cfg) image;
          autoStart = true;
          extraOptions = [ "--network=${cfg.network}" ];
          volumes = [ "${hostTokenPath}:${containerTokenPath}:ro" ];
          environment = {
            CLOUDFLARE_API_TOKEN_FILE = containerTokenPath;
            IP4_PROVIDER = cfg.ip4Provider;
            IP6_PROVIDER = cfg.ip6Provider;
            UPDATE_CRON = cfg.updateCron;
          }
          // domainEnv
          // sanitizedExtraEnv;
        };
      })
    ]
  );
}
