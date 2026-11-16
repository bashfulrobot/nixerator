# Orca headless server (https://orca.dev/docs/remote-servers)
#
# Runs `orca serve` as a user service so a desktop or mobile Orca can pair with
# this host over the tailnet and drive agents here. The package is the same
# AppImage wrapper the desktop module uses (modules/apps/gui/orca/build); the
# AppImage CLI runs without a display, verified with `orca serve --help` on srv.
#
# srv imports modules by hand, so hosts/srv/modules.nix names this path.
#
# First use, once after the rebuild (as the primary user, on srv):
#   orca pair                     # prints a pairing link, treat it like a password
#   orca account add --agent claude
# The service runs with --no-pairing, so no link ever lands in the journal.

{
  config,
  lib,
  pkgs,
  globals,
  versions,
  ...
}:

let
  cfg = config.server.orca;
  orca = pkgs.callPackage ../../apps/gui/orca/build { inherit versions; };
  bindAddress = globals.hosts.${cfg.host}.tailscale_ip;
in
{
  options.server.orca = {
    enable = lib.mkEnableOption "Orca headless server (`orca serve`) on the tailnet";

    host = lib.mkOption {
      type = lib.types.str;
      default = "srv";
      description = "Key in globals.hosts whose Tailscale IP the server binds to and advertises.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6768;
      description = "TCP port for `orca serve --port`. Opened on tailscale0 only.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Not on the public interface: pairing is the only auth, so the port is
    # reachable from the tailnet and nowhere else.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.port ];

    home-manager.users.${globals.user.name} = {
      home.packages = [ orca ];

      # default.target, not graphical-session.target: srv has no graphical
      # session. modules/system/linger keeps this user's systemd --user
      # instance up from boot. --supervise makes serve restart itself with
      # backoff; --no-pairing keeps the pairing link out of the journal.
      systemd.user.services.orca-serve = {
        Unit.Description = "Orca headless server (orca serve)";
        Install.WantedBy = [ "default.target" ];
        Service = {
          Type = "simple";
          ExecStart = lib.concatStringsSep " " [
            "${orca}/bin/orca"
            "serve"
            "--supervise"
            "--no-pairing"
            "--port ${toString cfg.port}"
            "--bind ${bindAddress}"
            "--pairing-address ${bindAddress}"
          ];
          Environment = [
            "PATH=${
              lib.makeBinPath [
                pkgs.llm-agents.claude-code
                pkgs.git
                pkgs.openssh
                pkgs.bash
                pkgs.coreutils
              ]
            }:/run/current-system/sw/bin:/etc/profiles/per-user/${globals.user.name}/bin"
          ];
          Restart = "on-failure";
          RestartSec = 10;
        };
      };
    };
  };
}
