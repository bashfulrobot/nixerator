{
  config,
  lib,
  pkgs,
  globals,
  versions,
  secretsLib,
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

  # `td` with TODOIST_API_TOKEN loaded from the secauto gopass store at each
  # launch, the same wrapper apps.cli.todoist-cli installs. Built here rather
  # than depending on that module's toggle, so the queries keep working if it
  # changes (claudoist does the same).
  todoistCli = secretsLib.withGopassEnv {
    inherit pkgs;
    pkg = pkgs.callPackage ../../apps/cli/todoist-cli/build { inherit versions; };
    bin = "td";
    envVar = "TODOIST_API_TOKEN";
    entry = "todoist/credential";
  };

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

  # Runs a Todoist filter kept in a file and writes the matching tasks as a
  # report. Usage: automations-td-query <job> <filter-file> <limit>. Lines
  # starting with # in the file are comments and the rest is joined into one
  # filter string, which reaches td as a single argument (never through a shell).
  tdQuery = pkgs.writeShellApplication {
    name = "automations-td-query";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
      pkgs.jq
      todoistCli
      report
    ];
    text = ''
      job=$1
      file=$2
      limit=$3

      filter=$(sed -e '/^[[:space:]]*#/d' "$file" | tr '\n' ' ' | sed -e 's/[[:space:]]*$//')
      if [ -z "''${filter//[[:space:]]/}" ]; then
        echo "automations-td-query: $file holds no filter" >&2
        exit 1
      fi

      json=$(td task list --filter "$filter" --limit "$limit" --json)
      count=$(jq '.results | length' <<< "$json")

      {
        printf '# %s\n\n' "$job"
        printf -- '- filter: %s\n' "$filter"
        printf -- '- tasks: %s\n\n' "$count"
        jq -r '.results[] | "- " + .content + " (p" + ((5 - .priority) | tostring) + (if .due then ", due " + .due.date else "" end) + ((.labels // []) | map(" @" + .) | join("")) + ") " + .url' <<< "$json"
      } | automations-report "$job" ok
    '';
  };

  # Runs when a job service fails (OnFailure=automations-failed@<job>), so the
  # Mac sees failed in latest.md instead of a stale ok. The instance is the job
  # name and the unit is automations-<job>. No secrets and no network, so it
  # works when the rest of the host does not.
  failed = pkgs.writeShellApplication {
    name = "automations-failed";
    runtimeInputs = [ report ];
    text = ''
      job=$1
      printf '# %s FAILED\n\nThe %s job failed. Run on %s: journalctl -u automations-%s\n' \
        "$job" "$job" ${lib.escapeShellArg hostName} "$job" \
        | automations-report "$job" failed
    '';
  };

  tdQueryJob = name: "td-${name}";

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

      tdQueries = lib.mkOption {
        default = { };
        example = lib.literalExpression ''
          {
            overdue = {
              file = ./queries/overdue.filter;
              schedule = "*-*-* 07:00:00";
            };
          }
        '';
        description = ''
          Todoist filter queries run on a schedule. Each entry keeps its filter
          in a file and writes reports/<host>/td-<name>/ through
          automations-td-query, using the srv `td` login from the secauto
          gopass store (todoist/credential).
        '';
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              file = lib.mkOption {
                type = lib.types.path;
                description = ''
                  File holding the Todoist filter. Lines starting with # are
                  comments, the rest is joined into one filter string.
                '';
              };

              schedule = lib.mkOption {
                type = lib.types.str;
                description = "systemd OnCalendar expression for this query.";
              };

              limit = lib.mkOption {
                type = lib.types.ints.positive;
                default = 100;
                description = "Most tasks written to the report.";
              };
            };
          }
        );
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ report ];

    systemd = lib.mkMerge [
      {
        services."automations-failed@" = {
          description = "Mark the %i job FAILED in the synced automations folder";
          serviceConfig = jobService // {
            ExecStart = "${lib.getExe failed} %i";
          };
        };
      }

      (lib.mkIf cfg.heartbeat.enable {
        services.automations-heartbeat = {
          description = "Write the host heartbeat report to the synced automations folder";
          onFailure = [ "automations-failed@heartbeat.service" ];
          serviceConfig = jobService // {
            ExecStart = lib.getExe heartbeat;
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
      })

      {
        services = lib.mapAttrs' (
          name: q:
          lib.nameValuePair "automations-${tdQueryJob name}" {
            description = "Run the ${name} Todoist query into the synced automations folder";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            onFailure = [ "automations-failed@${tdQueryJob name}.service" ];
            serviceConfig = jobService // {
              ExecStart = "${lib.getExe tdQuery} ${tdQueryJob name} ${q.file} ${toString q.limit}";
            };
          }
        ) cfg.tdQueries;

        timers = lib.mapAttrs' (
          name: q:
          lib.nameValuePair "automations-${tdQueryJob name}" {
            description = "Trigger for the ${name} Todoist query";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = q.schedule;
              Persistent = true;
              RandomizedDelaySec = "5m";
            };
          }
        ) cfg.tdQueries;
      }
    ];
  };
}
