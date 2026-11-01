{
  pkgs,
  config,
  lib,
  globals,
  inputs,
  secretsLib,
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
    };
  };
}
