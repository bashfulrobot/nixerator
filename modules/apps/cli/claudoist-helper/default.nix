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

  # HELPER_TOKEN is an op:// ref the gopass runner resolves from the secauto
  # store, so the value never enters the Nix store or the unit file.
  start = pkgs.writeShellScript "claudoist-helper-start" ''
    exec ${secretsLib.gopassRun { inherit pkgs; }} ${helperPkg}/bin/claudoist-helper
  '';
  # Publishes the resolved key to a runtime-dir file so the DankBar claudoist
  # widget (hyprflake) can read it at run time. Runs under gopassRun as
  # ExecStartPre, so HELPER_TOKEN already holds the resolved value; the script
  # never prints it. The file is 0600 in $XDG_RUNTIME_DIR (tmpfs, owner-only
  # dir), written to a temp name and renamed so a reader never sees a partial
  # key.
  writeToken = pkgs.writeShellScript "claudoist-token-write" ''
    set -eu
    umask 077
    dest="''${XDG_RUNTIME_DIR:?}/claudoist-token"
    # A writer killed between the write and the rename leaves a temp file that
    # holds the key; clear any from an earlier start.
    ${pkgs.coreutils}/bin/rm -f "$dest".??????
    tmp="$(${pkgs.coreutils}/bin/mktemp "$dest.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT
    printf '%s' "''${HELPER_TOKEN:?}" > "$tmp"
    ${pkgs.coreutils}/bin/chmod 600 "$tmp"
    ${pkgs.coreutils}/bin/mv -f "$tmp" "$dest"
    trap - EXIT
  '';

  # On stop, remove only temp leftovers. The key file itself stays across a
  # restart, so the widget reads "down" (helper stopped) and not "no token"
  # (key never written). It lives on tmpfs and goes at logout.
  stopClean = pkgs.writeShellScript "claudoist-token-clean" ''
    set -eu
    ${pkgs.coreutils}/bin/rm -f "''${XDG_RUNTIME_DIR:?}"/claudoist-token.??????
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
    # The DankBar claudoist widget (hyprflake) reads the key file written by
    # ExecStartPre below and talks to this helper's port.
    hyprflake.desktop.dank.claudoist = {
      enable = true;
      inherit (cfg) port;
    };

    home-manager.users.${globals.user.name} = {
      systemd.user.services.claudoist-helper = {
        Unit = {
          Description = "claudoist helper (Todoist task to Claude session)";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
          # ExecStartPre decrypts the key with gpg. Without a limit a missing
          # or broken gopass entry would retry the decrypt forever; stop after
          # 10 failures in 10 minutes and leave the unit failed.
          StartLimitIntervalSec = 600;
          StartLimitBurst = 10;
        };
        Service = {
          ExecStartPre = "${secretsLib.gopassRun { inherit pkgs; }} ${writeToken}";
          ExecStart = "${start}";
          ExecStopPost = "${stopClean}";
          Environment = [
            "HELPER_PORT=${toString cfg.port}"
            "HELPER_TOKEN=${cfg.tokenRef}"
            "HELPER_PYTHON=${pkgs.python3}/bin/python3"
            # Owner-only unix socket for the bar widget's /top.json read, so
            # the widget stops sending the key over TCP. %t is the user's
            # runtime dir. A helper build without the socket ignores it.
            "HELPER_SOCKET=%t/claudoist-helper.sock"
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
