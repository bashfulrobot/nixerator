{
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.cli.plakar;
  plakar = pkgs.callPackage ./build { inherit versions; };

  # Generate stores YAML for S3/B2-type stores
  s3Stores = lib.filterAttrs (_: s: s.type == "s3") cfg.stores;
  storesYaml = pkgs.writeText "plakar-stores.yaml" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: store:
        "${name}:\n  location: ${store.location}\n  access_key: ${store.accessKey}\n  secret_access_key: ${store.secretAccessKey}\n  use_tls: ${lib.boolToString store.useTls}\n  passphrase: ${store.passphrase}"
      ) s3Stores
    )
  );

  # Collect rclone-type stores for import commands
  rcloneStores = lib.filterAttrs (_: s: s.type == "rclone") cfg.stores;

  # Generate scheduler YAML
  schedulerYaml = pkgs.writeText "plakar-scheduler.yaml" (
    "agent:\n  tasks:\n"
    + lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: job:
        "    - name: ${name}\n      repository: \"${job.store}\"\n      backup:\n        path: ${lib.concatStringsSep "," job.paths}\n        interval: ${job.interval}\n        check: ${lib.boolToString job.check}"
      ) cfg.jobs
    )
  );

  # Activation script to import stores and initialize repos
  activationScript = pkgs.writeShellScript "plakar-activate" ''
    set -euo pipefail
    export PATH="${
      lib.makeBinPath [
        plakar
        pkgs.rclone
      ]
    }:$PATH"

    mkdir -p /etc/plakar

    # Import S3/B2 stores
    ${lib.optionalString (s3Stores != { }) ''
      plakar -config /etc/plakar store import -config ${storesYaml}
    ''}

    # Import rclone stores
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: store: ''
        rclone config show | plakar -config /etc/plakar store import -rclone ${store.rcloneRemote}
      '') rcloneStores
    )}

    # Initialize stores (skip if already initialized)
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: _: ''
        plakar -config /etc/plakar at "@${name}" create 2>/dev/null || true
      '') cfg.stores
    )}
  '';

  # plakar-mgr helper CLI (Fish script, matching backup-mgr pattern)
  plakar-mgr = ''
    #!/run/current-system/sw/bin/env fish

    set -x PLAKAR_BIN "${plakar}/bin/plakar"
    set -x PLAKAR_CONFIG "/etc/plakar"

    function init_stores
      $PLAKAR_BIN -config $PLAKAR_CONFIG store import -config ${storesYaml}
      ${lib.concatStringsSep "\n    " (
        lib.mapAttrsToList (name: _: ''
          $PLAKAR_BIN -config $PLAKAR_CONFIG at "@${name}" create 2>/dev/null; or true
        '') cfg.stores
      )}
      echo "All stores initialized."
    end

    function list_snapshots
      ${lib.concatStringsSep "\n    " (
        lib.mapAttrsToList (name: _: ''
          echo "--- Store: ${name} ---"
          $PLAKAR_BIN -config $PLAKAR_CONFIG at "@${name}" ls 2>/dev/null; or echo "(no snapshots or store not initialized)"
        '') cfg.stores
      )}
    end

    function check_store
      if test (count $argv) -lt 1
        echo "Usage: plakar-mgr -check <store-name>"
        return 1
      end
      $PLAKAR_BIN -config $PLAKAR_CONFIG at "@$argv[1]" check
    end

    function restore_snapshot
      if test (count $argv) -lt 2
        echo "Usage: plakar-mgr -restore <store-name> <snapshot-id>"
        return 1
      end
      $PLAKAR_BIN -config $PLAKAR_CONFIG at "@$argv[1]" restore $argv[2]
    end

    function check_status
      systemctl status plakar-scheduler.service
    end

    function check_logs
      journalctl -u plakar-scheduler.service
    end

    function show_help
      echo "Usage: plakar-mgr [OPTION]"
      echo "Options:"
      echo "  -help               Show this help message"
      echo "  -init               Initialize all configured stores"
      echo "  -list               List snapshots across all stores"
      echo "  -status             Show systemd service status"
      echo "  -logs               Show service journal logs"
      echo "  -restore <store> <snapshot>  Restore a specific snapshot"
      echo "  -check <store>      Run integrity check on a store"
    end

    if test (count $argv) -gt 0 -a "$argv[1]" = "-init"
      init_stores
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-list"
      list_snapshots
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-restore"
      restore_snapshot $argv[2..]
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-check"
      check_store $argv[2..]
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-status"
      check_status
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-logs"
      check_logs
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-help"
      show_help
    else
      show_help
    end
  '';

in
{
  options = {
    apps.cli.plakar = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Plakar backup tool with declarative store and job configuration.";
      };

      stores = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              type = lib.mkOption {
                type = lib.types.enum [
                  "s3"
                  "rclone"
                ];
                description = "Store backend type.";
              };

              location = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "S3-compatible endpoint URL (e.g., s3://s3.us-west-004.backblazeb2.com/mybucket/plakar).";
              };

              accessKey = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "S3/B2 access key ID.";
              };

              secretAccessKey = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "S3/B2 secret access key.";
              };

              useTls = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Use TLS for S3 connections.";
              };

              rcloneRemote = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Name of the rclone remote to import (e.g., 'mydrive'). Requires rclone to be configured.";
              };

              passphrase = lib.mkOption {
                type = lib.types.str;
                description = "Kloset store encryption passphrase.";
              };
            };
          }
        );
        default = { };
        description = "Named Plakar stores (backup destinations).";
      };

      jobs = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              store = lib.mkOption {
                type = lib.types.str;
                description = "Store name to back up to (references a key in stores, prefixed with @).";
              };

              paths = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                description = "Filesystem paths to back up.";
              };

              interval = lib.mkOption {
                type = lib.types.str;
                default = "24h";
                description = "Backup interval (Go duration: 1h, 24h, 168h, etc.).";
              };

              check = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Run integrity check after each backup.";
              };
            };
          }
        );
        default = { };
        description = "Named backup jobs.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      plakar
      pkgs.rclone
      (pkgs.writeScriptBin "plakar-mgr" plakar-mgr)
    ];

    system.activationScripts.plakar-setup = lib.stringAfter [ "etc" ] ''
      ${activationScript}
    '';

    systemd.services.plakar-scheduler = lib.mkIf (cfg.jobs != { }) {
      description = "Plakar backup scheduler";
      after = [
        "network-online.target"
        "multi-user.target"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${plakar}/bin/plakar -config /etc/plakar scheduler start -tasks ${schedulerYaml} -foreground";
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };
  };
}
