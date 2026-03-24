{
  lib,
  pkgs,
  config,
  globals,

  versions,
  ...
}:

let
  cfg = config.apps.cli.sled;
  sled = pkgs.callPackage ./build { inherit versions; };

  stateDir = "${globals.user.homeDirectory}/.local/share/sled";

  startScript = pkgs.writeShellScript "sled-start" ''
    set -euo pipefail
    export PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.nodejs
        pkgs.pnpm_10
        pkgs.wrangler
      ]
    }:$PATH"

    STATE_DIR="${stateDir}"
    mkdir -p "$STATE_DIR"

    # Symlink the built source into the mutable state dir
    # so wrangler can write .wrangler/ state alongside it
    if [ ! -d "$STATE_DIR/app" ]; then
      cp -r "${sled}/lib/sled/app" "$STATE_DIR/app"
      chmod -R u+w "$STATE_DIR/app"
    fi
    if [ ! -d "$STATE_DIR/server-client" ]; then
      cp -r "${sled}/lib/sled/server-client" "$STATE_DIR/server-client"
      chmod -R u+w "$STATE_DIR/server-client"
    fi

    # Symlink node_modules from the Nix store (per-workspace)
    ln -sfn "${sled}/lib/sled/node_modules" "$STATE_DIR/node_modules"
    ln -sfn "${sled}/lib/sled/app/node_modules" "$STATE_DIR/app/node_modules"
    ln -sfn "${sled}/lib/sled/server-client/node_modules" "$STATE_DIR/server-client/node_modules"

    # Copy root config files
    for f in package.json pnpm-workspace.yaml pnpm-lock.yaml; do
      if [ -f "${sled}/lib/sled/$f" ]; then
        cp -f "${sled}/lib/sled/$f" "$STATE_DIR/$f"
      fi
    done

    # Run migrations using system wrangler (npm workerd binary is not NixOS-compatible)
    # Mirrors app/scripts/run-migrations.sh with all ALTER TABLE steps
    cd "$STATE_DIR/app"
    d1() { wrangler d1 execute sled --local "$@" 2>/dev/null || true; }
    col_exists() {
      wrangler d1 execute sled --local \
        --command "SELECT 1 FROM pragma_table_info('$1') WHERE name='$2' LIMIT 1;" \
        --json 2>/dev/null | grep -q '"results":\[{' && return 0 || return 1
    }

    # 0001: base schema
    d1 --file=migrations/0001_init.sql
    # 0002: Claude support
    col_exists agents type       || d1 --command "ALTER TABLE agents ADD COLUMN type TEXT DEFAULT 'gemini';"
    col_exists users anthropic_api_key || d1 --command "ALTER TABLE users ADD COLUMN anthropic_api_key TEXT;"
    # 0003: yolo mode
    col_exists agents yolo       || d1 --command "ALTER TABLE agents ADD COLUMN yolo INTEGER DEFAULT 0;"
    # 0004: workdir
    col_exists agents workdir    || d1 --command "ALTER TABLE agents ADD COLUMN workdir TEXT;"
    # 0005: default user/session
    d1 --file=migrations/0005_default_user.sql
    # 0006: voice selection
    col_exists agents voice      || d1 --command "ALTER TABLE agents ADD COLUMN voice TEXT;"
    col_exists users default_voice || d1 --command "ALTER TABLE users ADD COLUMN default_voice TEXT;"
    # 0007: agent title
    col_exists agents title      || d1 --command "ALTER TABLE agents ADD COLUMN title TEXT;"

    # Start sled (wrangler dev on the configured port, bound to all interfaces)
    exec wrangler dev \
      --port ${toString cfg.port} \
      --ip 0.0.0.0 \
      src/index.tsx
  '';
in
{
  options.apps.cli.sled = {
    enable = lib.mkEnableOption "Sled voice-controlled web UI for coding agents";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8787;
      description = "Port for the Sled server.";
    };

    auth = {
      user = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "HTTP Basic Auth username. Set both user and pass to enable auth.";
      };

      pass = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "HTTP Basic Auth password. Set both user and pass to enable auth.";
      };
    };

    disableVoice = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable voice mode and connections to Layercode's API.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    home-manager.users.${globals.user.name} = {
      home.packages = [ sled ];

      systemd.user.services.sled = {
        Unit = {
          Description = "Sled voice-controlled coding agent UI";
          After = [ "network.target" ];
        };
        Service = {
          Type = "simple";
          Environment = [
            "PATH=${
              lib.makeBinPath [
                pkgs.nodejs
                pkgs.pnpm_10
              ]
            }:$PATH"
          ]
          ++ lib.optional (cfg.auth.user != null) "BASIC_AUTH_USER=${cfg.auth.user}"
          ++ lib.optional (cfg.auth.pass != null) "BASIC_AUTH_PASS=${cfg.auth.pass}"
          ++ lib.optional cfg.disableVoice "DISABLE_VOICE_MODE=true";
          ExecStart = toString startScript;
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    };
  };
}
