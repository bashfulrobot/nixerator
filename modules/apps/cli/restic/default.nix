{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.apps.cli.restic;
  bcfg = cfg.backup;

  backup-mgr = ''
    #!/run/current-system/sw/bin/env fish

    set -x RESTIC_BIN "/run/current-system/sw/bin/restic"

    set -x RESTIC_HOST (hostname)
    set -x RESTIC_REPOSITORY "${bcfg.repository}"
    set -x AWS_ACCESS_KEY_ID "${bcfg.awsAccessKeyId}"
    set -x AWS_SECRET_ACCESS_KEY "${bcfg.awsSecretAccessKey}"
    set -x AWS_DEFAULT_REGION "${bcfg.awsRegion}"
    set -x RESTIC_PASSWORD "${bcfg.password}"

    function init_repo
      $RESTIC_BIN -r $RESTIC_REPOSITORY init
    end

    function restore_backup
      $RESTIC_BIN -r $RESTIC_REPOSITORY restore latest --target ${bcfg.restorePath}
    end

    function list_backups
      $RESTIC_BIN -r $RESTIC_REPOSITORY snapshots
    end

    function run_backup
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

        repository = lib.mkOption {
          type = lib.types.str;
          description = "Restic repository URL (e.g., s3:s3.us-west-000.backblazeb2.com/bucket-name).";
        };

        password = lib.mkOption {
          type = lib.types.str;
          description = "Restic repository password.";
        };

        awsAccessKeyId = lib.mkOption {
          type = lib.types.str;
          description = "AWS/B2 access key ID.";
        };

        awsSecretAccessKey = lib.mkOption {
          type = lib.types.str;
          description = "AWS/B2 secret access key.";
        };

        awsRegion = lib.mkOption {
          type = lib.types.str;
          description = "AWS/B2 region.";
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
