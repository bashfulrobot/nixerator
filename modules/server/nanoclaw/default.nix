{
  lib,
  pkgs,
  config,
  versions,
  ...
}:
# NanoClaw (github.com/nanocoai/nanoclaw): one Node.js host process that
# spawns one Docker container per agent session, with the OneCLI Agent Vault
# as its credential gateway. Upstream ships no NixOS module and no all-in-one
# image, so this is new packaging, kept close to upstream's host-native
# layout. Operator guide (provisioning, first run, re-auth, verification):
# extras/docs/nanoclaw/README.md.
#
# Units, in start order:
#   docker-network-onecli     oneshot: the private `onecli` bridge network
#   nanoclaw-onecli-env       oneshot, root: renders onecli.env.tpl and
#                             postgres.env.tpl into /run/nanoclaw-onecli/ from
#                             the agenix DB-password file (runtime only)
#   docker-onecli-postgres    OneCLI's database (no host port)
#   docker-onecli             OneCLI vault + gateway; API and proxy published
#                             on 127.0.0.1 only
#   docker-onecli-gateway     (egressLockdown) socat relay exposing ONLY the
#                             proxy port to agent containers (see below)
#   nanoclaw-vault-sync       oneshot, DynamicUser: pushes the agenix
#                             setup-token into the vault as the `Anthropic`
#                             secret over OneCLI's local API
#   nanoclaw-agent-image      oneshot: `docker build` of upstream's
#                             container/Dockerfile from the store copy
#   nanoclaw                  the host process
#
# Secret flow (why nothing reaches /nix/store): the only secret values are the
# two agenix files. Nix handles their PATHS (strings), never their contents:
# no readFile, no interpolation of a value, no builtins.* on them. Each unit
# reads them through systemd LoadCredential= at runtime. The Claude token goes
# file -> jq --rawfile -> curl stdin -> OneCLI vault; it never lands on argv,
# in an env var, or in the host's .env. The DB password is rendered into
# /run (tmpfs). The host .env (hostEnvFile below) is a store file on purpose:
# it holds no secret, which is the whole point of a credential gateway.
let
  cfg = config.server.nanoclaw;
  inherit (cfg) onecli;

  pkg = cfg.package;
  root = "${pkg}/share/nanoclaw";
  inherit (pkg.passthru) nodejs;
  docker = config.virtualisation.docker.package;

  # NanoClaw names its image, systemd unit and container labels after an
  # install slug (sha1 of the project path unless overridden). Pin it so the
  # image tag the build unit produces is the one the host spawns.
  image = "nanoclaw-agent-v2-${cfg.installId}";
  imageRef = "${image}:latest";
  sourceLabel = "org.nixos.nanoclaw.source";

  # Hardening over upstream's topology. OneCLI 1.41 serves its admin API
  # (secrets CRUD, unauthenticated in local mode) from the same container as
  # the proxy. Upstream publishes both on docker0 and, under egress lockdown,
  # attaches that whole container to the agents' network -- so an agent can
  # PATCH the Anthropic secret's hostPattern and have the gateway inject the
  # real token into requests to a host it controls (verified against 1.41.0).
  # Here the API is loopback-only (the host process is the only client) and
  # agents reach a relay container that forwards the proxy port and nothing
  # else. Without lockdown, the proxy port alone is also published on docker0.
  apiUrl = "http://127.0.0.1:${toString onecli.appPort}";
  gatewayUrl = "http://127.0.0.1:${toString onecli.gatewayPort}";
  gatewayContainer = if cfg.egressLockdown then "onecli-gateway" else "onecli";

  relayImage = pkgs.dockerTools.streamLayeredImage {
    name = "nanoclaw-onecli-relay";
    tag = "nix";
    config = {
      Entrypoint = [
        "${pkgs.socat}/bin/socat"
        "TCP-LISTEN:10255,fork,reuseaddr"
        "TCP:onecli:10255"
      ];
      User = "65534:65534";
    };
  };

  # Every code path upstream reads relative to process.cwd(). These become
  # symlinks into the store; everything else in dataDir is real mutable state.
  codeEntries = [
    ".claude"
    "bin"
    "config-examples"
    "container"
    "dist"
    "docs"
    "node_modules"
    "package.json"
    "pnpm-lock.yaml"
    "pnpm-workspace.yaml"
    "scripts"
    "setup"
    "src"
    "templates"
    "tsconfig.json"
    "versions.json"
  ];

  # Upstream's settings live in <project>/.env, parsed in-process. A few
  # (CONTAINER_IMAGE, NANOCLAW_INSTALL_ID) are read from process.env only, so
  # the same attrset is also exported to the unit and the operator commands.
  # Nothing here is a secret -- ONECLI_URL is a loopback address and the
  # gateway needs no API key in local mode.
  hostEnv = {
    NANOCLAW_GATEWAY_PROVIDER = "onecli";
    ONECLI_URL = apiUrl;
    ONECLI_GATEWAY_CONTAINER = gatewayContainer;
    NANOCLAW_INSTALL_ID = cfg.installId;
    CONTAINER_IMAGE = imageRef;
    CONTAINER_IMAGE_BASE = image;
    NANOCLAW_EGRESS_LOCKDOWN = lib.boolToString cfg.egressLockdown;
    TZ = cfg.timeZone;
  }
  // lib.optionalAttrs (cfg.assistantName != null) { ASSISTANT_NAME = cfg.assistantName; }
  // cfg.extraSettings;
  hostEnvFile = pkgs.writeText "nanoclaw.env" (
    lib.concatStrings (lib.mapAttrsToList (k: v: "${k}=${v}\n") hostEnv)
  );

  # Runs one of upstream's TypeScript entry points the way `pnpm exec tsx`
  # would, from dataDir, as the service user (the CLI socket is 0600).
  mkTsxCommand =
    name: entry:
    pkgs.writeShellScriptBin name ''
      set -euo pipefail
      if [ "$(${pkgs.coreutils}/bin/id -un)" != ${lib.escapeShellArg cfg.user} ]; then
        exec /run/wrappers/bin/sudo -u ${lib.escapeShellArg cfg.user} -- "$0" "$@"
      fi
      cd ${lib.escapeShellArg cfg.dataDir}
      ${lib.toShellVars hostEnv}
      export ${lib.concatStringsSep " " (lib.attrNames hostEnv)}
      export PATH=${lib.makeBinPath [ docker ]}:$PATH
      exec ${nodejs}/bin/node ${root}/node_modules/tsx/dist/cli.mjs ${root}/${entry} "$@"
    '';

  chatCmd = mkTsxCommand "nanoclaw-chat" "scripts/chat.ts";
  nclCmd = mkTsxCommand "nanoclaw-ncl" "src/cli/client.ts";
  initAgentCmd = mkTsxCommand "nanoclaw-init-cli-agent" "scripts/init-cli-agent.ts";

  # Verification helper: proves from inside each running agent container that
  # no raw Anthropic credential exists in its environment or filesystem. It
  # never needs the real token -- it looks for the credential SHAPE
  # (sk-ant-...), so it cannot leak what it is checking for.
  checkCredsCmd = pkgs.writeShellScriptBin "nanoclaw-check-agent-creds" ''
    set -uo pipefail
    export PATH=${
      lib.makeBinPath [
        docker
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gnused
      ]
    }
    ids=$(docker ps --filter label=nanoclaw-install=${cfg.installId} --format '{{.ID}}')
    if [ -z "$ids" ]; then
      echo "No running agent containers (label nanoclaw-install=${cfg.installId})." >&2
      echo "Send a message first (nanoclaw-chat hello), then re-run within the idle window." >&2
      exit 2
    fi
    rc=0
    for id in $ids; do
      name=$(docker inspect --format '{{.Name}}' "$id")
      echo "== $name"
      echo "-- Anthropic/Claude env vars (expect only placeholder values):"
      docker exec "$id" env | grep -E '^(ANTHROPIC_[A-Z_]*|CLAUDE_CODE_OAUTH_TOKEN)=' || echo "   (none)"
      if docker exec "$id" env | grep -qE 'sk-ant-'; then
        echo "FAIL: an sk-ant- credential is present in the container environment"
        rc=1
      else
        echo "OK:   no sk-ant- value in the environment"
      fi
      hits=$(docker exec "$id" sh -c \
        'grep -rIl --exclude-dir=proc --exclude-dir=sys --exclude-dir=dev --exclude-dir=node_modules --exclude-dir=.bun -e "sk-ant-oat" -e "sk-ant-api" / 2>/dev/null' \
        || true)
      if [ -n "$hits" ]; then
        echo "FAIL: files containing an sk-ant- credential:"
        echo "$hits" | sed 's/^/   /'
        rc=1
      else
        echo "OK:   no sk-ant- credential anywhere on the container filesystem"
      fi
    done
    exit "$rc"
  '';

  # Token -> vault. Idempotent: PATCH the existing `Anthropic` secret's value
  # (keeps its id, so per-agent grants survive a re-auth) or POST a new one.
  # The token only ever travels file -> jq --rawfile -> curl stdin.
  vaultSync = pkgs.writeShellScript "nanoclaw-vault-sync" ''
    set -euo pipefail
    export PATH=${
      lib.makeBinPath [
        pkgs.curl
        pkgs.jq
        pkgs.coreutils
        pkgs.gnugrep
      ]
    }
    api=${lib.escapeShellArg apiUrl}
    token="$CREDENTIALS_DIRECTORY/claude-token"
    name=${lib.escapeShellArg cfg.vaultSecretName}

    # Shape check without printing anything derived from the value.
    if ! tr -d '[:space:]' < "$token" | grep -qE '^sk-ant-oat[0-9]*-[A-Za-z0-9_-]+$'; then
      echo "claude token file is not an sk-ant-oat... setup-token (refusing API keys and junk)" >&2
      exit 1
    fi

    for _ in $(seq 1 60); do
      curl -fsS --noproxy '*' "$api/v1/health" >/dev/null 2>&1 && break
      sleep 2
    done
    curl -fsS --noproxy '*' "$api/v1/health" >/dev/null

    id=$(curl -fsS --noproxy '*' "$api/v1/secrets" \
      | jq -r --arg n "$name" 'map(select(.name == $n and .type == "anthropic")) | first | .id // empty')

    if [ -n "$id" ]; then
      jq -n --rawfile v "$token" '{value: ($v | gsub("\\s"; ""))}' \
        | curl -fsS --noproxy '*' -X PATCH -H 'Content-Type: application/json' \
            --data-binary @- "$api/v1/secrets/$id" >/dev/null
      echo "Updated vault secret '$name' ($id) from the agenix setup-token."
    else
      jq -n --rawfile v "$token" --arg n "$name" \
        '{name: $n, type: "anthropic", value: ($v | gsub("\\s"; "")), hostPattern: "api.anthropic.com"}' \
        | curl -fsS --noproxy '*' -X POST -H 'Content-Type: application/json' \
            --data-binary @- "$api/v1/secrets" >/dev/null
      echo "Created vault secret '$name' from the agenix setup-token."
    fi
  '';

  renderOnecliEnv = pkgs.writeShellScript "nanoclaw-onecli-env" ''
    set -euo pipefail
    export PATH=${
      lib.makeBinPath [
        pkgs.gettext
        pkgs.coreutils
        pkgs.gnugrep
      ]
    }
    ONECLI_DB_PASSWORD=$(tr -d '[:space:]' < "$CREDENTIALS_DIRECTORY/db-password")
    # It lands inside a postgresql:// URL, so keep it to URL-unreserved chars.
    if ! printf '%s' "$ONECLI_DB_PASSWORD" | grep -qE '^[A-Za-z0-9._~-]{16,}$'; then
      echo "OneCLI DB password must be >=16 chars of [A-Za-z0-9._~-] (use: openssl rand -hex 32)" >&2
      exit 1
    fi
    export ONECLI_DB_PASSWORD
    umask 077
    out=/run/nanoclaw-onecli
    envsubst '$ONECLI_DB_PASSWORD' < ${./onecli.env.tpl} > "$out/onecli.env.tmp"
    envsubst '$ONECLI_DB_PASSWORD' < ${./postgres.env.tpl} > "$out/postgres.env.tmp"
    chmod 600 "$out/onecli.env.tmp" "$out/postgres.env.tmp"
    mv "$out/onecli.env.tmp" "$out/onecli.env"
    mv "$out/postgres.env.tmp" "$out/postgres.env"
  '';

  buildImage = pkgs.writeShellScript "nanoclaw-agent-image" ''
    set -euo pipefail
    export PATH=${
      lib.makeBinPath [
        docker
        pkgs.coreutils
      ]
    }
    want=${lib.escapeShellArg "${pkg}"}
    have=$(docker image inspect --format '{{index .Config.Labels "${sourceLabel}"}}' ${imageRef} 2>/dev/null || true)
    if [ "$have" = "$want" ]; then
      echo "Agent image ${imageRef} already built from $want"
      exit 0
    fi
    lock=$(sha256sum ${root}/container/agent-runner/bun.lock | cut -d' ' -f1)
    echo "Building ${imageRef} from ${root}/container (was: ''${have:-absent})"
    # Same inputs as upstream's container/build.sh on its default build path;
    # the extra label records which store path the image came from.
    docker build \
      --build-arg AGENT_RUNNER_LOCK_SHA256="$lock" \
      ${lib.optionalString cfg.cjkFonts "--build-arg INSTALL_CJK_FONTS=true"} \
      --label ${sourceLabel}="$want" \
      -t ${imageRef} \
      ${root}/container
  '';

  preStart = pkgs.writeShellScript "nanoclaw-prestart" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [ pkgs.coreutils ]}
    cd ${lib.escapeShellArg cfg.dataDir}
    mkdir -p data groups store logs
    ${lib.concatMapStrings (e: ''
      if [ -e ${e} ] && [ ! -L ${e} ]; then
        echo "refusing to replace real path ${cfg.dataDir}/${e} with a store symlink" >&2
        exit 1
      fi
      ln -sfn ${root}/${e} ${e}
    '') codeEntries}
    ln -sfn ${hostEnvFile} .env
    # The upgrade tripwire refuses to boot code that no sanctioned upgrade
    # recorded. A NixOS rebuild IS this install's upgrade path (migrations run
    # on host start), so stamp the running version. The empty version arg
    # makes upstream read it from package.json (the Nix version string carries
    # an -unstable suffix that would never match). No .git here, so commit and
    # tree record as "unknown" and the tripwire matches on version alone.
    ${nodejs}/bin/node ${root}/node_modules/tsx/dist/cli.mjs \
      ${root}/scripts/upgrade-state.ts set "" nixos
  '';
in
{
  options.server.nanoclaw = {
    enable = lib.mkEnableOption "NanoClaw personal AI assistant with the OneCLI credential gateway";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./build { inherit versions; };
      defaultText = lib.literalExpression "pkgs.callPackage ./build { inherit versions; }";
      description = "NanoClaw build (with the /add-onecli skill applied).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "nanoclaw";
      description = ''
        Non-root system user the host runs as. It is added to the `docker`
        group so it can spawn agent containers, which makes it root-equivalent
        on this host (upstream's architecture requires it).
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "nanoclaw";
      description = "Primary group of the service user.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/nanoclaw";
      description = ''
        Project root and working directory: data/ (central + session DBs),
        groups/, store/, logs/, plus store symlinks for the code.
      '';
    };

    installId = lib.mkOption {
      type = lib.types.strMatching "[a-z0-9][a-z0-9_-]{0,31}";
      default = "nanoclaw";
      description = "NANOCLAW_INSTALL_ID: names the agent image and labels this install's containers.";
    };

    assistantName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Andy";
      description = "ASSISTANT_NAME; null keeps upstream's default.";
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = config.time.timeZone;
      defaultText = lib.literalExpression "config.time.timeZone";
      description = "TZ passed to the host (scheduled tasks, timestamps).";
    };

    egressLockdown = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        NANOCLAW_EGRESS_LOCKDOWN: agent containers run on an `--internal`
        Docker network whose only reachable hop is the OneCLI gateway, so the
        injected proxy cannot be bypassed.
      '';
    };

    cjkFonts = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Build the agent image with CJK fonts (~200MB).";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        CONTAINER_MEMORY_LIMIT = "4g";
      };
      description = ''
        Extra NON-SECRET lines for the host's .env. This file is in
        /nix/store, so a secret here is a leak: credentials belong in the
        OneCLI vault, never in this attrset.
      '';
    };

    claudeTokenFile = lib.mkOption {
      type = lib.types.path;
      example = lib.literalExpression "config.age.secrets.nanoclaw-claude-token.path";
      description = ''
        Runtime path (agenix) of the `claude setup-token` OAuth token
        (sk-ant-oat...). Read only by nanoclaw-vault-sync via LoadCredential;
        the host process and agent containers never see it.
      '';
    };

    secretsRestartTriggers = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [ ];
      example = lib.literalExpression "[ config.age.secrets.nanoclaw-claude-token.file ]";
      description = ''
        Values whose change re-runs nanoclaw-vault-sync on the next rebuild.
        Pass the agenix `.file` (the ENCRYPTED .age store path, which changes
        whenever the payload is re-encrypted) so a re-auth lands on `just qr`
        without a manual restart. Never pass anything holding a plaintext value.
      '';
    };

    vaultSecretName = lib.mkOption {
      type = lib.types.str;
      default = "Anthropic";
      description = "Name of the OneCLI vault secret (upstream's setup uses `Anthropic`).";
    };

    onecli = {
      image = lib.mkOption {
        type = lib.types.str;
        # 1.41.0 is the gateway version NanoClaw's add-onecli skill sanctions
        # (.claude/skills/add-onecli/versions.json). Digest-pinned. Pre-2.0, so
        # it is the all-in-one image from upstream's docker-compose.legacy.yml.
        default = "ghcr.io/onecli/onecli:1.41.0@sha256:66dc84042310cab762ed3b1f71a98349a72aa132ad44651b7ae76c371aaafe6b";
        description = "OneCLI vault/gateway image.";
      };

      postgresImage = lib.mkOption {
        type = lib.types.str;
        default = "postgres:18-alpine@sha256:77f585114c32fbca283dc835b0596f4e52b51b4c6662d7810b2f4084f60a1873";
        description = "PostgreSQL image backing the vault.";
      };

      bindAddress = lib.mkOption {
        type = lib.types.str;
        default = "172.17.0.1";
        description = ''
          docker0 address the PROXY port is published on when egressLockdown
          is off, so agents reach it via host.docker.internal (upstream's
          bind rule: docker0, never 0.0.0.0). Unused under lockdown. The
          admin API is never published here; it stays on 127.0.0.1.
        '';
      };

      appPort = lib.mkOption {
        type = lib.types.port;
        default = 10254;
        description = "OneCLI API/dashboard port.";
      };

      gatewayPort = lib.mkOption {
        type = lib.types.port;
        default = 10255;
        description = "OneCLI credential-injecting proxy port.";
      };

      dbPasswordFile = lib.mkOption {
        type = lib.types.path;
        example = lib.literalExpression "config.age.secrets.nanoclaw-onecli-db-password.path";
        description = ''
          Runtime path (agenix) of the OneCLI PostgreSQL password. Rendered
          into /run/nanoclaw-onecli/*.env from the checked-in templates.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(lib.hasPrefix "/nix/store" (toString cfg.claudeTokenFile));
        message = "server.nanoclaw.claudeTokenFile points into /nix/store; it must be an agenix runtime path.";
      }
      {
        assertion = !(lib.hasPrefix "/nix/store" (toString onecli.dbPasswordFile));
        message = "server.nanoclaw.onecli.dbPasswordFile points into /nix/store; it must be an agenix runtime path.";
      }
      {
        assertion = config.virtualisation.oci-containers.backend == "docker";
        message = "server.nanoclaw needs virtualisation.oci-containers.backend = \"docker\" (NanoClaw drives the Docker CLI).";
      }
    ];

    virtualisation = {
      docker = {
        enable = true;
        # srv bridges libvirt VMs (the darkstar Talos nodes) over br0. By
        # default Docker flips the iptables FORWARD policy to DROP, which can
        # cut bridged/forwarded VM traffic once br_netfilter is loaded. Keep
        # Docker's own per-network rules but leave the policy alone.
        daemon.settings.ip-forward-no-drop = lib.mkDefault true;
      };
      oci-containers = {
        backend = lib.mkDefault "docker";
        containers = {
          onecli-postgres = {
            image = onecli.postgresImage;
            environment = {
              POSTGRES_USER = "onecli";
              POSTGRES_DB = "onecli";
            };
            environmentFiles = [ "/run/nanoclaw-onecli/postgres.env" ];
            # Named volumes, same names upstream's compose project uses.
            volumes = [ "onecli_pgdata:/var/lib/postgresql" ];
            networks = [ "onecli" ];
            # Unlike upstream's compose, no host port: only OneCLI needs it.
          };

          # `onecli` is also the DNS name the relay forwards to.
          onecli = {
            inherit (onecli) image;
            dependsOn = [ "onecli-postgres" ];
            ports = [
              "127.0.0.1:${toString onecli.appPort}:10254"
              "127.0.0.1:${toString onecli.gatewayPort}:10255"
            ]
            ++ lib.optional (!cfg.egressLockdown) "${onecli.bindAddress}:${toString onecli.gatewayPort}:10255";
            environment = {
              APP_URL = apiUrl;
              GATEWAY_API_URL = gatewayUrl;
              INTERNAL_API_URL = "http://localhost:10254";
            };
            environmentFiles = [ "/run/nanoclaw-onecli/onecli.env" ];
            # Holds the vault's secret-encryption-key: back this volume up
            # together with onecli_pgdata or the vault is unreadable.
            volumes = [ "onecli_app-data:/app/data" ];
            networks = [ "onecli" ];
            extraOptions = [ "--add-host=host.docker.internal:host-gateway" ];
          };
        }
        // lib.optionalAttrs cfg.egressLockdown {
          # What NanoClaw attaches to the agents' --internal network as
          # host.docker.internal (ONECLI_GATEWAY_CONTAINER). It speaks TCP to
          # onecli:10255 and nothing else, so the admin API on :10254 is
          # unreachable from agent containers. Built from nixpkgs' socat; no
          # registry pull. Proxy auth is the per-agent aoc_ token in the
          # proxy URL, not the peer address, so relaying is transparent.
          onecli-gateway = {
            image = "nanoclaw-onecli-relay:nix";
            imageStream = relayImage;
            dependsOn = [ "onecli" ];
            networks = [ "onecli" ];
          };
        };
      };
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
      home = cfg.dataDir;
      extraGroups = [ "docker" ];
      description = "NanoClaw host";
    };
    users.groups.${cfg.group} = { };

    systemd.tmpfiles.settings."10-nanoclaw".${cfg.dataDir}.d = {
      inherit (cfg) user group;
      mode = "0750";
    };

    environment.systemPackages = [
      chatCmd
      nclCmd
      initAgentCmd
      checkCredsCmd
    ];

    systemd.services = {
      docker-network-onecli = {
        description = "Docker network for the OneCLI vault";
        after = [ "docker.service" ];
        requires = [ "docker.service" ];
        path = [ docker ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          docker network inspect onecli >/dev/null 2>&1 || docker network create onecli
        '';
      };

      nanoclaw-onecli-env = {
        description = "Render OneCLI container env files from templates (runtime only)";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "nanoclaw-onecli";
          RuntimeDirectoryMode = "0700";
          LoadCredential = [ "db-password:${onecli.dbPasswordFile}" ];
          ExecStart = renderOnecliEnv;
          UMask = "0077";
        };
      };

      docker-onecli-postgres = {
        after = [
          "docker-network-onecli.service"
          "nanoclaw-onecli-env.service"
        ];
        requires = [
          "docker-network-onecli.service"
          "nanoclaw-onecli-env.service"
        ];
      };

      docker-onecli = {
        after = [
          "docker-network-onecli.service"
          "nanoclaw-onecli-env.service"
        ];
        requires = [
          "docker-network-onecli.service"
          "nanoclaw-onecli-env.service"
        ];
      };

      nanoclaw-vault-sync = {
        description = "Load the Claude setup-token into the OneCLI vault";
        after = [ "docker-onecli.service" ];
        requires = [ "docker-onecli.service" ];
        # Re-run on every rebuild that changes the secret path or script.
        restartTriggers = [
          cfg.claudeTokenFile
          vaultSync
        ]
        ++ cfg.secretsRestartTriggers;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          DynamicUser = true;
          LoadCredential = [ "claude-token:${cfg.claudeTokenFile}" ];
          ExecStart = vaultSync;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          NoNewPrivileges = true;
        };
      };

      nanoclaw-agent-image = {
        description = "Build the NanoClaw agent container image";
        after = [
          "docker.service"
          "network-online.target"
        ];
        requires = [ "docker.service" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = cfg.user;
          Group = cfg.group;
          ExecStart = buildImage;
          TimeoutStartSec = "45min";
          Restart = "on-failure";
          RestartSec = "2min";
        };
      };

      nanoclaw = {
        description = "NanoClaw host";
        wantedBy = [ "multi-user.target" ];
        after = [
          "docker.service"
          "network-online.target"
          "nanoclaw-vault-sync.service"
          "nanoclaw-agent-image.service"
        ]
        ++ lib.optional cfg.egressLockdown "docker-onecli-gateway.service";
        requires = [
          "docker.service"
          "nanoclaw-vault-sync.service"
        ];
        # wants, not requires: a registry hiccup during the image build should
        # not keep the host (and its CLI socket) down; the build unit retries.
        # Lockdown fails closed (no spawn) if the relay is missing, so it is
        # wanted too.
        wants = [
          "network-online.target"
          "nanoclaw-agent-image.service"
        ]
        ++ lib.optional cfg.egressLockdown "docker-onecli-gateway.service";
        path = [
          docker
          pkgs.procps
          pkgs.coreutils
        ];
        environment = hostEnv // {
          HOME = cfg.dataDir;
          NODE_ENV = "production";
        };
        restartTriggers = [ hostEnvFile ];
        serviceConfig = {
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.dataDir;
          ExecStartPre = preStart;
          ExecStart = "${nodejs}/bin/node ${root}/dist/index.js";
          Restart = "on-failure";
          RestartSec = "10s";
          UMask = "0027";
          # Cosmetic next to docker-group membership, but it keeps the host
          # process itself from writing outside its state directory.
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ cfg.dataDir ];
        };
      };
    };
  };
}
