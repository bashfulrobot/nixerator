{
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.cli.gurk;
  gurk = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.gurk.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable gurk-rs, a Signal Messenger TUI client.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ gurk ];
  };
}
