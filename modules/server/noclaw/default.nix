{
  config,
  lib,
  pkgs,
  globals,
  ...
}:
# noclaw -- proof-of-concept always-on Claude Code Remote Control session.
#
# Goal: one persistent "noclaw" remote session, rooted in ~/git/noclaw, that is
# always running and comes back after a reboot.
#
# Design notes (verified June 2026):
#   * A Remote Control session is bound to its local process: a reboot kills it
#     and the session ends, so no live duplicate is ever left behind. We
#     therefore don't try to resume across reboots -- we just respawn a fresh
#     server-mode session on each start. (Resume-across-restart is an open,
#     stale Anthropic request: #29748 / #30447.)
#   * Respawning is a feature, not a cost: each fresh session flushes context
#     and keeps the transcript bounded. The recycle timer leans into that by
#     restarting on a schedule so context never accumulates on long uptimes.
#   * `claude remote-control` server mode is foreground + TTY-bound (no headless
#     flag yet, #30447), so the service runs it under a `script(1)` pty.
#   * `--spawn session` keeps it to a single session; `--name noclaw` is the
#     title shown at claude.ai/code.
#   * Server mode shows a *cloud* icon in the app, not the computer/green-dot
#     icon the docs attach to Remote Control. This is cosmetic: execution is
#     local (verified 2026-06-26 via hostname + an on-disk nonce read back from
#     the phone). The interactive form (`claude --remote-control`) shows the
#     computer icon, but we intentionally keep server mode and don't chase it.
#   * A lingering systemd *user* service gives always-on + boot-survival while
#     running as the user, so it uses ~/.claude OAuth credentials and inherits
#     the workspace trust + project config (.claude/) recorded for the directory.
let
  cfg = config.server.noclaw;

  user = globals.user.name;
  homeDir = globals.user.homeDirectory;
  workDir = "${homeDir}/git/noclaw";

  claude = "${pkgs.llm-agents.claude-code}/bin/claude";

  # mkdir + cd here rather than via systemd WorkingDirectory, so the unit still
  # starts on the very first boot before the directory exists.
  startScript = pkgs.writeShellScript "noclaw-rc-start" ''
    set -euo pipefail
    mkdir -p "${workDir}"
    cd "${workDir}"
    exec ${claude} remote-control --name noclaw --spawn session
  '';
in
{
  options.server.noclaw = {
    enable = lib.mkEnableOption "always-on Claude Code Remote Control session (noclaw POC)";

    recycle = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Periodically restart the session to flush accumulated context and keep the transcript bounded.";
      };
      onCalendar = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 04:00:00";
        example = "Mon *-*-* 04:00:00";
        description = "systemd OnCalendar expression for the periodic context-flush restart.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Run the user's systemd instance at boot without an interactive login, so
    # the service comes back after a reboot.
    users.users.${user}.linger = true;

    home-manager.users.${user} = {
      systemd.user.services = {
        noclaw = {
          Unit = {
            Description = "Always-on Claude Code Remote Control session (noclaw)";
            After = [ "network-online.target" ];
            Wants = [ "network-online.target" ];
          };

          Service = {
            Type = "simple";

            # Server mode is interactive/TTY-bound (no headless flag yet);
            # `script` allocates a pty so it runs cleanly under systemd with
            # no terminal attached.
            ExecStart = "${pkgs.util-linux}/bin/script -q -f -c ${startScript} /dev/null";

            # Always-on + self-healing: restart on crash, sleep-wake, or the
            # ~10-min network-loss timeout that ends a remote session.
            Restart = "always";
            RestartSec = "15";

            # Pin the tools the harness itself needs (the `claude` binary, and
            # jq for the PreToolUse hook) from the nix store first. Then append
            # the host system + user-profile paths so approved bin/ programs can
            # use host-level tooling (hostname, etc.). The gate-bash hook still
            # confines the agent to ./bin, so this broad PATH is only ever
            # reachable through a reviewed program -- never an ad-hoc command.
            Environment = [
              "PATH=${
                lib.makeBinPath [
                  pkgs.llm-agents.claude-code
                  pkgs.git
                  pkgs.coreutils
                  pkgs.bash
                  pkgs.gnugrep
                  pkgs.gnused
                  pkgs.findutils
                  pkgs.jq
                ]
              }:/run/current-system/sw/bin:/etc/profiles/per-user/${user}/bin"
            ];
          };

          Install.WantedBy = [ "default.target" ];
        };
      }
      // lib.optionalAttrs cfg.recycle.enable {
        # Oneshot that flushes context by restarting the session. Restart=always
        # on the main unit brings it straight back as a fresh session.
        noclaw-recycle = {
          Unit.Description = "Flush noclaw context by restarting the session";
          Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.systemd}/bin/systemctl --user restart noclaw.service";
          };
        };
      };

      systemd.user.timers = lib.optionalAttrs cfg.recycle.enable {
        noclaw-recycle = {
          Unit.Description = "Periodic noclaw context flush";
          Timer = {
            OnCalendar = cfg.recycle.onCalendar;
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    };
  };
}
