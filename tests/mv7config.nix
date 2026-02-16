{ inputs, system }:
let
  lib = inputs.nixpkgs.lib;
  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [
      (final: prev: {
        mv7config = prev.callPackage ../packages/mv7config { };
      })
    ];
  };
  eval = lib.nixosSystem {
    inherit system;
    modules = [
      {
        nixpkgs.pkgs = pkgs;
        system.stateVersion = "24.11";
      }
      ../modules/apps/gui/mv7config
      {
        apps.gui.mv7config.enable = true;
      }
    ];
  };
in
lib.runTests {
  mv7configAddsPackage = {
    expr = lib.elem pkgs.mv7config eval.config.environment.systemPackages;
    expected = true;
  };
  mv7configAddsUdevRule = {
    expr = lib.elem pkgs.mv7config eval.config.services.udev.packages;
    expected = true;
  };
}
