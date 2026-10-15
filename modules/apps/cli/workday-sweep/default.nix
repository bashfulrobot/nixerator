{
  pkgs,
  config,
  lib,
  globals,
  ...
}:
let
  cfg = config.apps.cli.workday-sweep;

  # The sweep is a Claude Code run, not a standalone program. Every piece of
  # work it does needs the desktop's own MCP servers and credentials: the
  # Google Calendar MCP for the day's events, Slack for reply detection, Aha
  # and Jira for feature-request status, and `td` for Todoist. A cloud routine
  # has none of those, which is why this is a local user timer rather than a
  # scheduled agent.
  #
  # It runs headless through `claude -p`. The prompt only names the skill and
  # the mode; every rule lives in the skill, so changing behaviour means
  # editing the skill rather than rebuilding this module.
  sweepScript = pkgs.writeShellApplication {
    name = "workday-sweep";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      set -euo pipefail

      out_dir="${cfg.briefDir}"
      mkdir -p "$out_dir"

      # The brief's own filename is tomorrow's date when the sweep runs before
      # midnight-adjacent hours, and today's otherwise. The timer fires at
      # 05:30, so the brief is always for the day that is starting.
      day="$(date +%F)"

      if ! command -v claude >/dev/null; then
        echo "workday-sweep: claude not on PATH, cannot run the sweep" >&2
        exit 127
      fi

      # --permission-mode acceptEdits keeps the run unattended for the writes
      # the skill is allowed to make. The skill's own data-safety rules are
      # what stop it closing or deleting anything: every closure is proposed
      # in the brief and approved by hand.
      claude -p \
        --permission-mode acceptEdits \
        "Use the dk:workday skill in sweep mode for $day. Write the brief to $out_dir/brief-$day.md. Draft only; send nothing and close nothing." \
        >"$out_dir/.sweep-$day.log" 2>&1

      if [ ! -s "$out_dir/brief-$day.md" ]; then
        echo "workday-sweep: no brief written for $day, see $out_dir/.sweep-$day.log" >&2
        exit 1
      fi

      echo "workday-sweep: wrote $out_dir/brief-$day.md"
    '';
  };
in
{
  options.apps.cli.workday-sweep = {
    enable = lib.mkEnableOption ''
      the workday-sweep command: a headless `claude -p` run of the dk:workday
      skill's sweep mode, which syncs external activity into Todoist, drafts
      nudges and answers, and writes the morning brief
    '';

    briefDir = lib.mkOption {
      type = lib.types.str;
      default = "${globals.user.homeDirectory}/day";
      description = ''
        Directory the sweep writes `brief-YYYY-MM-DD.md` into, alongside a
        dotfile run log per day. Kept in the home directory rather than a
        repository because a brief names customers and open commitments.
      '';
    };

    schedule = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Run the sweep on a systemd user timer. The primary user lingers (see
          modules/system/linger), so the user manager is up from boot and the
          timer fires whether or not anyone has logged in.
        '';
      };

      onCalendar = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 05:30:00";
        description = ''
          Systemd timer OnCalendar schedule. 05:30 so the brief is waiting
          before the first meeting; the measured calendar has events from
          07:00.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = [ sweepScript ];
    })

    (lib.mkIf (cfg.enable && cfg.schedule.enable) {
      # A user timer, not a system one, so the sweep runs as the user whose
      # Claude credentials, MCP servers and td login it uses.
      #
      # Persistent means a run missed while the machine was off happens at the
      # next boot rather than being skipped. That matters more here than for a
      # report: a skipped sweep means a day with no brief, and the chase and
      # expiry clocks silently do not advance.
      home-manager.users.${globals.user.name} = {
        systemd.user.timers.workday-sweep = {
          Unit.Description = "workday sweep timer";
          Timer = {
            Persistent = true;
            OnCalendar = cfg.schedule.onCalendar;
            # The sweep talks to five external services, so a fixed firing
            # time would hammer them all at the same second every morning.
            RandomizedDelaySec = "5m";
          };
          Install.WantedBy = [ "timers.target" ];
        };

        systemd.user.services.workday-sweep = {
          # Retry, for the same reason aha-fr-report does: the user manager
          # starts early in the boot and Persistent fires the catch-up run
          # straight away, potentially before DHCP and tailscale have settled.
          # There is no network-online.target in the user manager to order
          # against. Persistent also stamps on trigger rather than on success,
          # so a first attempt against a dead network would consume the missed
          # occurrence and the day would have no brief.
          #
          # 6 starts at 5 minutes apart covers roughly 25 minutes from the
          # first attempt, inside the 1h limit interval.
          #
          # Retrying is safe because the sweep is idempotent in the ways that
          # matter: comments are only filed for activity newer than the last
          # logged comment, label writes are read-modify-write on the governed
          # slots, and the brief is overwritten rather than appended.
          Unit = {
            Description = "workday sweep: build tomorrow's brief";
            StartLimitIntervalSec = "1h";
            StartLimitBurst = 6;
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${sweepScript}/bin/workday-sweep";
            Restart = "on-failure";
            RestartSec = "5m";
          };
        };
      };
    })
  ];
}
