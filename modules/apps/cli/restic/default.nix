{
  pkgs,
  config,
  lib,
  globals,
  ...
}:
let
  cfg = config.apps.cli.restic;
  bcfg = cfg.backup;

  profile = bcfg.secretsProfile;
  secretsFile = bcfg.secretsFile;
  jqBin = "${pkgs.jq}/bin/jq";

  backup-mgr = ''
    #!/run/current-system/sw/bin/env fish

    set -x RESTIC_BIN "/run/current-system/sw/bin/restic"
    set -x RESTIC_HOST (hostname)

    # Credentials are NOT baked into this script (it lives world-readable in
    # /nix/store, on every user's PATH). load_secrets reads them at runtime
    # from the off-store, 0600 file written by render-secrets, so the B2 keys
    # and restic password never enter the store. See extras/docs/secrets.md.
    function load_secrets
      set -l secrets_file "${secretsFile}"
      if not test -r "$secrets_file"
        echo "backup-mgr: secrets file $secrets_file is missing or unreadable." >&2
        echo "Run 'just render-secrets' (or push from a peer) and retry." >&2
        exit 1
      end
      set -l jq "${jqBin}"
      set -gx RESTIC_REPOSITORY ($jq -r '.restic.${profile}.restic_repository' "$secrets_file")
      set -gx AWS_ACCESS_KEY_ID ($jq -r '.restic.${profile}.b2_account_id' "$secrets_file")
      set -gx AWS_SECRET_ACCESS_KEY ($jq -r '.restic.${profile}.b2_account_key' "$secrets_file")
      set -gx AWS_DEFAULT_REGION ($jq -r '.restic.${profile}.region' "$secrets_file")
      set -gx RESTIC_PASSWORD ($jq -r '.restic.${profile}.restic_password' "$secrets_file")
    end

    function init_repo
      load_secrets
      $RESTIC_BIN -r $RESTIC_REPOSITORY init
    end

    function restore_backup
      load_secrets
      $RESTIC_BIN -r $RESTIC_REPOSITORY restore latest --target ${bcfg.restorePath}
    end

    function list_backups
      load_secrets
      $RESTIC_BIN -r $RESTIC_REPOSITORY snapshots
    end

    function run_backup
      load_secrets
      $RESTIC_BIN -r $RESTIC_REPOSITORY backup ${lib.concatStringsSep " " bcfg.backupPaths}
      $RESTIC_BIN -r $RESTIC_REPOSITORY forget --prune --host $RESTIC_HOST --keep-daily ${toString bcfg.keepDaily} --keep-weekly ${toString bcfg.keepWeekly} --keep-monthly ${toString bcfg.keepMonthly} --keep-yearly ${toString bcfg.keepYearly}
    end

    function check_status
      systemctl status backup-mgr.timer
      systemctl status backup-mgr.service
    end

    function check_service_logs
      journalctl -u backup-mgr.service
    end

    function check_timer_logs
      journalctl -u backup-mgr.timer
    end

    function check_logs
      check_service_logs
      check_timer_logs
    end

    function show_help
      echo "Usage: backup-mgr [OPTION]"
      echo "Options:"
      echo "  -help           Show this help message"
      echo "  -init           Initialize the repository"
      echo "  -backup         Run a manual backup now"
      echo "  -list           List all snapshots"
      echo "  -restore        Restore the latest backup"
      echo "  -status         Check systemd timer and service status"
      echo "  -logs           Show all logs (service + timer)"
      echo "  -service-logs   Show service logs only"
      echo "  -timer-logs     Show timer logs only"
    end

    if test (count $argv) -gt 0 -a "$argv[1]" = "-init"
      init_repo
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-backup"
      run_backup
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-list"
      list_backups
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-restore"
      restore_backup
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-status"
      check_status
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-logs"
      check_logs
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-timer-logs"
      check_timer_logs
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-service-logs"
      check_service_logs
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-help"
      show_help
    else
      show_help
    end
  '';

in
{
  options = {
    apps.cli.restic = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable restic backup tool.";
      };

      backup = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable scheduled restic backups with backup-mgr.";
        };

        secretsProfile = lib.mkOption {
          type = lib.types.str;
          description = ''
            Key under `.restic` in the rendered secrets file selecting this
            host's credential set (e.g. "srv" or "workstation"). The
            repository, password, B2 keys, and region are read from
            `<secretsFile>.restic.<secretsProfile>.*` at runtime by backup-mgr,
            so they never enter the world-readable /nix/store.
          '';
        };

        secretsFile = lib.mkOption {
          type = lib.types.str;
          default = "${globals.user.homeDirectory}/.config/nixos-secrets/secrets.json";
          description = ''
            Path to the off-store JSON secrets file (rendered by
            render-secrets) that backup-mgr reads credentials from at runtime.
          '';
        };

        backupPaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "Paths to back up.";
        };

        restorePath = lib.mkOption {
          type = lib.types.str;
          default = "/tmp/restic-restore";
          description = "Path where backups will be restored.";
        };

        schedule = lib.mkOption {
          type = lib.types.str;
          default = "*-*-* 03:00:00";
          description = "Systemd timer OnCalendar schedule for backups.";
        };

        keepDaily = lib.mkOption {
          type = lib.types.int;
          default = 7;
          description = "Number of daily snapshots to keep.";
        };

        keepWeekly = lib.mkOption {
          type = lib.types.int;
          default = 4;
          description = "Number of weekly snapshots to keep.";
        };

        keepMonthly = lib.mkOption {
          type = lib.types.int;
          default = 12;
          description = "Number of monthly snapshots to keep.";
        };

        keepYearly = lib.mkOption {
          type = lib.types.int;
          default = 2;
          description = "Number of yearly snapshots to keep.";
        };
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = [
        pkgs.restic
      ];
    })

    (lib.mkIf (cfg.enable && bcfg.enable) {
      environment.systemPackages = [
        (pkgs.writeScriptBin "backup-mgr" backup-mgr)
      ];

      systemd = {
        timers.backup-mgr = {
          description = "backup-mgr timer";
          enable = true;
          wantedBy = [ "timers.target" ];
          partOf = [ "backup-mgr.service" ];
          timerConfig = {
            Persistent = "true";
            OnCalendar = bcfg.schedule;
          };
        };

        services.backup-mgr = {
          description = "Backup with restic";
          enable = true;
          serviceConfig = {
            Type = "simple";
            ExecStart = "/run/current-system/sw/bin/fish /run/current-system/sw/bin/backup-mgr";
          };
          wantedBy = [ "multi-user.target" ];
        };
      };
    })
  ];
}
