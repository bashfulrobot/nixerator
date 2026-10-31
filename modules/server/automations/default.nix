{
  config,
  lib,
  pkgs,
  globals,
  ...
}:

# Scheduled jobs that write markdown reports into the Syncthing-shared
# ~/automations folder, so any workstation reads them without asking the host
# that ran the job. Layout: reports/<host>/<job>/YYYY-MM-DD.md plus latest.md.
# A host writes only under its own reports/<host>/ directory, so Syncthing never
# has two writers on one file. See extras/docs/automations.md.

let
  cfg = config.server.automations;
  hostName = config.networking.hostName;

  # Writes one report. Usage: automations-report <job> <status>, markdown body
  # on stdin. Writes the dated file and latest.md, each by rename, so a reader
  # (or Syncthing) never sees a half-written report, then prunes old dated
  # files.
  #
  # The temp files are named .syncthing.<random>.tmp on purpose. Syncthing skips
  # files with that prefix and suffix, which is how it names its own temp files
  # (LIKELY, from Syncthing's temp-file naming; not checked against its source),
  # so a scan during the write does not sync the partial file.
  report = pkgs.writeShellApplication {
    name = "automations-report";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      job=$1
      status=$2
      dir=${lib.escapeShellArg cfg.reportsDir}/$job
      mkdir -p "$dir"

      day=$(date -u +%F)
      dated=$(mktemp --suffix=.tmp "$dir/.syncthing.XXXXXX")
      latest=$(mktemp --suffix=.tmp "$dir/.syncthing.XXXXXX")

      {
        printf -- '---\nhost: %s\njob: %s\nstatus: %s\nrun_at: %s\n---\n\n' \
          ${lib.escapeShellArg hostName} "$job" "$status" "$(date -u +%FT%TZ)"
        cat
      } > "$dated"
      cp "$dated" "$latest"
      chmod 0644 "$dated" "$latest"
      mv "$dated" "$dir/$day.md"
      mv "$latest" "$dir/latest.md"

      find "$dir" -maxdepth 1 -name '20??-??-??.md' -mtime +${toString cfg.keepDays} -delete
    '';
  };

  # Proves the pipeline end to end and doubles as a host health note: uptime
  # and any failed units. Needs no secrets and no network.
  heartbeat = pkgs.writeShellApplication {
    name = "automations-heartbeat";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
      report
    ];
    text = ''
      failed=$(systemctl list-units --failed --no-legend --plain | cut -d' ' -f1)
      if [ -n "$failed" ]; then
        count=$(printf '%s\n' "$failed" | wc -l)
        status=degraded
      else
        count=0
        status=ok
      fi
      hours=$(( $(cut -d. -f1 /proc/uptime) / 3600 ))

      {
        printf '# %s heartbeat\n\n' ${lib.escapeShellArg hostName}
        printf -- '- uptime: %s hours\n' "$hours"
        printf -- '- failed units: %s\n' "$count"
        if [ -n "$failed" ]; then
          printf '\n'
          while IFS= read -r unit; do
            printf -- '- %s\n' "$unit"
          done <<< "$failed"
        fi
      } | automations-report heartbeat "$status"
    '';
  };

  # Runs when the heartbeat service fails, so the Mac sees FAILED in latest.md
  # instead of a stale ok. No secrets and no network, so it works when the rest
  # of the host does not.
  heartbeatFailed = pkgs.writeShellApplication {
    name = "automations-heartbeat-failed";
    runtimeInputs = [ report ];
    text = ''
      printf '# %s heartbeat FAILED\n\nThe heartbeat job failed. Run on %s: journalctl -u automations-heartbeat\n' \
        ${lib.escapeShellArg hostName} ${lib.escapeShellArg hostName} \
        | automations-report heartbeat failed
    '';
  };

  jobService = {
    Type = "oneshot";
    User = globals.user.name;
    Group = "users";
    NoNewPrivileges = true;
    PrivateTmp = true;
    LockPersonality = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
  };
in
{
  options = {
    server.automations = {
      enable = lib.mkEnableOption "scheduled jobs that write reports into the synced automations folder";

      reportsDir = lib.mkOption {
        type = lib.types.str;
        default = "${globals.paths.automations}/reports/${hostName}";
        defaultText = lib.literalExpression ''"''${globals.paths.automations}/reports/''${config.networking.hostName}"'';
        description = ''
          Directory this host writes reports under. Keep the host name in it:
          one writer per directory is what keeps Syncthing conflict-free.
        '';
      };

      keepDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 30;
        description = "Days of dated reports to keep per job. latest.md is never pruned.";
      };

      heartbeat = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Write a daily host heartbeat report. It tests the sync path with no external dependency.";
        };

        schedule = lib.mkOption {
          type = lib.types.str;
          default = "*-*-* 06:30:00";
          description = "systemd OnCalendar expression for the heartbeat.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ report ];

    systemd = lib.mkIf cfg.heartbeat.enable {
      services.automations-heartbeat = {
        description = "Write the host heartbeat report to the synced automations folder";
        onFailure = [ "automations-heartbeat-failed.service" ];
        serviceConfig = jobService // {
          ExecStart = lib.getExe heartbeat;
        };
      };

      services.automations-heartbeat-failed = {
        description = "Mark the heartbeat report FAILED in the synced automations folder";
        serviceConfig = jobService // {
          ExecStart = lib.getExe heartbeatFailed;
        };
      };

      # Persistent=true runs a heartbeat missed during downtime at next boot.
      timers.automations-heartbeat = {
        description = "Daily trigger for the host heartbeat report";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.heartbeat.schedule;
          Persistent = true;
          RandomizedDelaySec = "15m";
        };
      };
    };
  };
}
