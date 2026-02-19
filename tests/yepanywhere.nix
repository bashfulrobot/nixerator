{ inputs, system }:
let
  lib = inputs.nixpkgs.lib;
  eval = lib.nixosSystem {
    inherit system;
    modules = [
      {
        system.stateVersion = "24.11";
      }
      ../modules/apps/cli/yepanywhere
      {
        apps.cli.yepanywhere.enable = true;
      }
    ];
  };

  yepanywhereIsInstalled =
    lib.any
      (pkg:
        let
          name =
            if builtins.isAttrs pkg && pkg ? name then
              pkg.name
            else if builtins.isString pkg then
              pkg
            else
              "";
        in
        lib.hasPrefix "yepanywhere" name)
      eval.config.environment.systemPackages;
in
lib.runTests {
  yepanywhereAddsPackage = {
    expr = yepanywhereIsInstalled;
    expected = true;
  };
}
