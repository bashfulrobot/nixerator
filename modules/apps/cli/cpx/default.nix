{
  globals,
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.cli.cpx;
  cpx = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.cpx.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable cpx - a fast, Rust-based cp replacement with progress bars and resume capability.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cpx ];

    home-manager.users.${globals.user.name} = {
      programs.fish.shellAliases = {
        cp = "cpx";
      };
    };
  };
}
