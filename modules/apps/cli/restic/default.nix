{ globals, pkgs, config, lib, ... }:

let
  cfg = config.apps.cli.restic;
  lazyrestic = pkgs.callPackage ./build/lazyrestic.nix { };

in
{
  options = {
    apps.cli.restic.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable restic backup tools including restic, autorestic, and lazyrestic TUI.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.restic
      pkgs.autorestic
      lazyrestic
    ];
  };
}
