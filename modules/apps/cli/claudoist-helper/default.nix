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
    home-manager.users.${globals.user.name} = {
      systemd.user.services.claudoist-helper = {
        Unit = {
          Description = "claudoist helper (Todoist task to Claude session)";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${start}";
          Environment = [
            "HELPER_PORT=${toString cfg.port}"
            "HELPER_TOKEN=${cfg.tokenRef}"
            "HELPER_PYTHON=${pkgs.python3}/bin/python3"
            # kitty and claude come from the system and user profiles.
            "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${globals.user.name}/bin"
          ];
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
