{
  lib,
  pkgs,
  config,
  globals,
  versions,
  ...
}:

let
  cfg = config.apps.cli.happy;
  happy = pkgs.callPackage ./build { inherit versions; };
in
{
  options.apps.cli.happy.enable =
    lib.mkEnableOption "Happy -- mobile/web remote control for Claude Code sessions (happy.engineering)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.packages = [ happy ];

      # Declared here (rather than relying on `happy daemon install`, which
      # would self-register an equivalent unit imperatively) so the always-on
      # daemon is reproducible across rebuilds and hosts like every other
      # service in this repo. `daemon start-sync` is the foreground variant
      # `daemon start` uses internally under the hood (it forks this exact
      # subcommand detached, waits for it to come up, then exits) -- running
      # it directly as the unit's own process means systemd supervises the
      # real daemon, not a launcher that exits immediately.
      #
      # `default.target`, not `graphical-session.target`: this must come up
      # on srv, which never has a graphical session. `modules/system/linger`
      # already keeps this user's systemd --user instance running from boot
      # on both qbert and srv, so `default.target` is reached without an
      # interactive login.
      #
      # PATH is explicit rather than inherited, mirroring server.claudoist /
      # server.incidentInvestigator's own systemd services: `claude` has to
      # resolve for the daemon to spawn real sessions. Unlike those two
      # (which shell out to a small, fixed set of tools), a Happy session can
      # run arbitrary project tooling, so the fallback system + per-user
      # profile directories are appended too rather than curating an exact
      # tool list.
      #
      # Not gated on prior `happy auth` pairing: with no credentials yet,
      # the daemon's own startup throws and this unit restarts every
      # RestartSec until the user runs `happy` interactively once to pair,
      # then it settles. Same accepted posture as server.claudoist's
      # missing-prerequisite case (see the comment in hosts/srv/modules.nix).
      systemd.user.services.happy-daemon = {
        # No After/Wants on network-online.target: that's a system-level
        # target, invisible to this user's own systemd --user instance, so
        # ordering on it here would be a silent no-op. Restart=always below
        # covers the early-boot race with network coming up instead.
        Unit.Description = "Happy daemon -- lets the mobile/web client spawn and manage Claude Code sessions on this host (happy.engineering)";
        Install.WantedBy = [ "default.target" ];
        Service = {
          Type = "simple";
          ExecStart = "${happy}/bin/happy daemon start-sync";
          Environment = [
            "PATH=${
              lib.makeBinPath [
                happy
                pkgs.llm-agents.claude-code
                pkgs.git
                pkgs.bash
                pkgs.coreutils
              ]
            }:/run/current-system/sw/bin:/etc/profiles/per-user/${globals.user.name}/bin"
          ];
          Restart = "always";
          RestartSec = 10;
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };
    };

    # First-time pairing is still a manual, interactive step: run `happy`
    # once on this host to print a QR/login link for the mobile/web client
    # to scan. The unit above starts unconditionally at boot either way; it
    # simply idles-and-restarts (see the Restart note above) until that
    # pairing has happened once.
  };
}
