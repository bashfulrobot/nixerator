{ globals, pkgs, config, lib, secrets, ... }:
let
  cfg = config.server.restic;
  username = globals.user.name;

  backup-mgr = ''
    #!/run/current-system/sw/bin/env fish

    set -x RESTIC_BIN "/run/current-system/sw/bin/restic"

    set -x RESTIC_HOST (hostname)
    set -x RESTIC_REPOSITORY "${cfg.repository}"
    set -x AWS_ACCESS_KEY_ID "${cfg.awsAccessKeyId}"
    set -x AWS_SECRET_ACCESS_KEY "${cfg.awsSecretAccessKey}"
    set -x AWS_DEFAULT_REGION "${cfg.awsRegion}"
    set -x RESTIC_PASSWORD "${cfg.password}"

    function init_repo
      $RESTIC_BIN -r $RESTIC_REPOSITORY init
    end

    function restore_backup
      $RESTIC_BIN -r $RESTIC_REPOSITORY restore latest --target ${cfg.restorePath}
    end

    function list_backups
      $RESTIC_BIN -r $RESTIC_REPOSITORY snapshots
    end

    function run_backup
      $RESTIC_BIN -r $RESTIC_REPOSITORY backup ${lib.concatStringsSep " " cfg.backupPaths}
      $RESTIC_BIN -r $RESTIC_REPOSITORY forget --prune --keep-daily ${toString cfg.keepDaily} --keep-weekly ${toString cfg.keepWeekly} --keep-monthly ${toString cfg.keepMonthly} --keep-yearly ${toString cfg.keepYearly}
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

    function show_help
      echo "Usage: $argv[1] [OPTION]"
      echo "Options:"
      echo "  -help           Show this help message"
      echo "  -init           Initialize the repository"
      echo "  -list-backups   List all backups"
      echo "  -service-logs   Check the logs of the backup service"
      echo "  -restore        Restore the latest backup"
      echo "  -status         Check the status of the systemd timer and service"
      echo "  -timer-logs     Check the logs of the systemd timer"
    end

    if test (count $argv) -gt 0 -a "$argv[1]" = "-init"
      init_repo
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-restore"
      restore_backup
    else if test (count $argv) -gt 0 -a "$argv[1]" = "-list-backups"
      list_backups
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
      run_backup
    end
  '';

in {

  options = {
    server.restic = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable restic backup system with systemd timer.";
      };

      repository = lib.mkOption {
        type = lib.types.str;
        description = "Restic repository URL.";
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
        default = [ "/srv/nfs" ];
        description = "Paths to backup.";
      };

      restorePath = lib.mkOption {
        type = lib.types.str;
        default = "/srv/nfs/restores";
        description = "Path where backups will be restored.";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 03:00:00";
        description = "Systemd timer schedule for backups.";
      };

      keepDaily = lib.mkOption {
        type = lib.types.int;
        default = 7;
        description = "Number of daily backups to keep.";
      };

      keepWeekly = lib.mkOption {
        type = lib.types.int;
        default = 4;
        description = "Number of weekly backups to keep.";
      };

      keepMonthly = lib.mkOption {
        type = lib.types.int;
        default = 12;
        description = "Number of monthly backups to keep.";
      };

      keepYearly = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Number of yearly backups to keep.";
      };
    };
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      (writeScriptBin "backup-mgr" backup-mgr)
      # Backrest from nixpkgs; wrapped to use nixpkgs restic via BACKREST_RESTIC_COMMAND.
      backrest
      restic
    ];

    systemd.timers.backup-mgr = {
      description = "backup-mgr timer";
      enable = true;
      wantedBy = [ "timers.target" ];
      partOf = [ "backup-mgr.service" ];
      timerConfig = {
        Persistent = "true";
        OnCalendar = cfg.schedule;
      };
    };

    systemd.services.backup-mgr = {
      description = "Backup with restic";
      enable = true;
      serviceConfig = {
        Type = "simple";
        ExecStart = "/run/current-system/sw/bin/fish /run/current-system/sw/bin/backup-mgr";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
