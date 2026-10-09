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
  claudePath = "${pkgs.llm-agents.claude-code}/bin/claude";
  antigravityEnabled = config.apps.cli.antigravity.enable;
in
{
  options.apps.cli.happy.enable =
    lib.mkEnableOption "Happy -- mobile/web remote control for Claude Code sessions (happy.engineering)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = lib.mkMerge [
      {
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
        # tool list. `agy` (Antigravity CLI) joins the same PATH, gated on
        # apps.cli.antigravity.enable, so `happy agy` sessions (the daemon's
        # AgyBackend, upstream slopus/happy src/agy/) can spawn it too.
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
                lib.makeBinPath (
                  [
                    happy
                    pkgs.llm-agents.claude-code
                    pkgs.git
                    pkgs.bash
                    pkgs.coreutils
                  ]
                  ++ lib.optional antigravityEnabled pkgs.google-antigravity-cli
                )
              }:/run/current-system/sw/bin:/etc/profiles/per-user/${globals.user.name}/bin"
              # happy-coder's own `claude` discovery (scripts/claude_version_utils.cjs)
              # resolves `which claude` via fs.realpathSync, lands on
              # bin/.claude-wrapped (the nix wrapper's real target), sees no
              # .js/.cjs/.exe suffix, and -- wrongly assuming any extensionless
              # resolved path is an npm shim -- goes looking for a sibling
              # node_modules/@anthropic-ai/claude-code that doesn't exist here.
              # It then falls through npm/Bun/Homebrew/native-installer probes,
              # all irrelevant on NixOS, and reports "Claude Code is not
              # installed". HAPPY_CLAUDE_PATH is checked first, unconditionally,
              # bypassing that broken shim heuristic entirely.
              "HAPPY_CLAUDE_PATH=${claudePath}"
              # agy has no equivalent detection bug (findAgyBin's `command -v
              # agy` probe works fine), so it just needs to be on PATH above --
              # no HAPPY_AGY_PATH override required.
            ];
            Restart = "always";
            RestartSec = 10;
            StandardOutput = "journal";
            StandardError = "journal";
          };
        };
      }

      # Same happy-coder detection bug (see the Environment comment above)
      # also breaks a plain interactive `happy` launch, not just the daemon
      # unit's own spawns -- so the fix has to reach the login shell too.
      # Delivered via fish shellInit, not home.sessionVariables: this host's
      # fish does not source hm-session-vars, so home.sessionVariables never
      # reach the shell or its children (see the same reasoning in
      # modules/apps/cli/ollama and modules/apps/cli/fish). Gated on the fish
      # module so this stays a no-op where fish is not enabled.
      (lib.mkIf config.apps.cli.fish.enable {
        programs.fish.shellInit = ''
          set -gx HAPPY_CLAUDE_PATH "${claudePath}"
        '';
      })
    ];

    # First-time pairing is still a manual, interactive step: run `happy`
    # once on this host to print a QR/login link for the mobile/web client
    # to scan. The unit above starts unconditionally at boot either way; it
    # simply idles-and-restarts (see the Restart note above) until that
    # pairing has happened once.
  };
}
