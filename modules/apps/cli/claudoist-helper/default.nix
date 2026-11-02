{
  pkgs,
  config,
  lib,
  globals,
  inputs,
  secretsLib,
  versions,
  ...
}:
# claudoist-helper -- the laptop side of "send a Todoist task to Claude".
# A Todoist card button opens http://127.0.0.1:<port>/launch in the browser;
# the helper checks the token and opens kitty running
# `claude --name claudoist:<mode>:<id> "/dk:todoist-orchestrator <mode> <id>"`.
# The receiver is server.claudoist on srv. Design: docs/spec.md in the
# claudoist repo.
#
# Runs as a systemd user service tied to the graphical session, because kitty
# needs the session's Wayland display. UNVERIFIED: that the session imports
# WAYLAND_DISPLAY into the user manager (uwsm or hyprland's exec-once does).
let
  cfg = config.apps.cli.claudoist-helper;
  inherit (pkgs.stdenv.hostPlatform) system;
  helperPkg = inputs.claudoist.packages.${system}.helper;
  # Same custom-built gws the gws module installs (not in nixpkgs). Built here
  # so the freetime service works whether or not apps.cli.gws is enabled.
  gws = pkgs.callPackage ../gws/build { inherit versions; };
  # File name of the helper's unix socket inside the runtime dir. hyprflake owns
  # it so the widget and the unit cannot drift.
  inherit (config.hyprflake.desktop.dank.claudoist) socketName;

  # HELPER_TOKEN is an op:// ref the gopass runner resolves from the secauto
  # store, so the value never enters the Nix store or the unit file.
  start = pkgs.writeShellScript "claudoist-helper-start" ''
    exec ${secretsLib.gopassRun { inherit pkgs; }} ${helperPkg}/bin/claudoist-helper
  '';
  # The bar widget reads the helper over its owner-only unix socket and never
  # needs the key, so nothing writes the key to a file any more. On stop,
  # remove the socket (the helper does not unlink it on SIGTERM) so the widget
  # reads "down" while the helper is not running, and clear the key file and
  # temp files an earlier version of this unit left in the runtime dir.
  stopClean = pkgs.writeShellScript "claudoist-socket-clean" ''
    set -eu
    d="''${XDG_RUNTIME_DIR:?}"
    ${pkgs.coreutils}/bin/rm -f "$d/${socketName}" "$d"/claudoist-token "$d"/claudoist-token.??????
  '';
in
{
  options.apps.cli.claudoist-helper = {
    enable = lib.mkEnableOption "the claudoist helper (opens a Claude Code session in kitty for a Todoist task)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 47615;
      description = "Loopback port. Must match server.claudoist.helperBaseUrl.";
    };

    tokenRef = lib.mkOption {
      type = lib.types.str;
      default = "op://automation/claudoist/helper-token";
      description = "gopass reference (op:// form) for the shared launch token. Same entry as server.claudoist.helperTokenRef.";
    };

    freetime = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Run `claudoist-helper freetime` from a systemd user timer so
          ~/automations/claudoist/free-time.json stays current for the 05:30
          ranking on srv. srv ignores the file once it is older than 24 hours.
        '';
      };

      workHours = lib.mkOption {
        type = lib.types.str;
        default = "08:00-17:00";
        description = "Working hours, HH:MM-HH:MM, written to HELPER_WORK_HOURS for the freetime service.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # The DankBar claudoist widget (hyprflake) reads this helper over its unix
    # socket (HELPER_SOCKET below) and never sends the key over TCP: with
    # requireSocket a missing socket reads "down" in place of a TCP fallback.
    hyprflake.desktop.dank.claudoist = {
      enable = true;
      inherit (cfg) port;
      requireSocket = true;
    };

    home-manager.users.${globals.user.name} = {
      # On PATH so `claudoist-helper triage` and `proposals` run from a terminal.
      home.packages = [ helperPkg ];

      systemd.user.services.claudoist-helper = {
        Unit = {
          Description = "claudoist helper (Todoist task to Claude session)";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
          # The gopass runner decrypts the key with gpg at start. Without a limit
          # a missing or broken gopass entry would retry the decrypt forever;
          # stop after 10 failures in 10 minutes and leave the unit failed.
          StartLimitIntervalSec = 600;
          StartLimitBurst = 10;
        };
        Service = {
          ExecStart = "${start}";
          ExecStopPost = "${stopClean}";
          Environment = [
            "HELPER_PORT=${toString cfg.port}"
            "HELPER_TOKEN=${cfg.tokenRef}"
            "HELPER_PYTHON=${pkgs.python3}/bin/python3"
            # Owner-only unix socket for the bar widget's /top.json read, so
            # the widget never sends the key over TCP. %t is the user's runtime
            # dir (0700). A helper build without the socket ignores it.
            "HELPER_SOCKET=%t/${socketName}"
            # kitty and claude come from the system and user profiles.
            "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${globals.user.name}/bin"
          ];
          # A restart (a rebuild, systemctl restart) must not end the Claude
          # sessions the helper started. The default KillMode=control-group
          # would SIGTERM every process in the unit's cgroup, kitty and claude
          # included. "process" limits the kill to the helper itself.
          KillMode = "process";
          Restart = "on-failure";
          RestartSec = 15;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      # Refreshes free-time.json from the calendar (needs gws logged in).
      # A user timer that does not depend on the graphical session; the
      # primary user lingers, so it fires with nobody logged in. A failed run
      # (gws logged out, offline) logs and exits non-zero. No Restart=: the
      # next slot is at most 4 hours away.
      systemd.user.services.claudoist-freetime = lib.mkIf cfg.freetime.enable {
        Unit.Description = "claudoist free-time refresh (calendar to free-time.json)";
        Service = {
          Type = "oneshot";
          ExecStart = "${helperPkg}/bin/claudoist-helper freetime";
          TimeoutStartSec = 90;
          NoNewPrivileges = true;
          Environment = [
            "HELPER_WORK_HOURS=${cfg.freetime.workHours}"
            "PATH=${lib.makeBinPath [ gws ]}:/run/current-system/sw/bin:/etc/profiles/per-user/${globals.user.name}/bin"
          ];
        };
      };

      systemd.user.timers.claudoist-freetime = lib.mkIf cfg.freetime.enable {
        Unit.Description = "claudoist free-time refresh timer";
        Timer = {
          OnCalendar = [
            "Mon..Fri *-*-* 05:00:00"
            "Mon..Fri *-*-* 06,10,14,18:00:00"
          ];
          Persistent = true;
          RandomizedDelaySec = "2min";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
