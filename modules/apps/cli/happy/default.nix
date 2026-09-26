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
    };

    # First-time setup is interactive and out of scope for this module:
    #   1. `happy` pairs the current terminal session by printing a QR code
    #      (or a login link) for the mobile/web client to scan.
    #   2. `happy daemon start` runs a background service that lets the
    #      mobile/web client spawn and manage sessions on this host without
    #      an open terminal -- the point of enabling this on the always-on
    #      srv and the usually-up qbert rather than the often-off
    #      donkeykong. It registers its own systemd --user unit, which
    #      survives logout/reboot because `modules/system/linger` already
    #      keeps this user's systemd instance running on both hosts.
  };
}
