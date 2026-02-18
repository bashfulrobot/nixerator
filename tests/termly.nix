{ inputs, system }:
let
  lib = inputs.nixpkgs.lib;
  eval = lib.nixosSystem {
    inherit system;
    modules = [
      {
        system.stateVersion = "24.11";
      }
      ../modules/apps/cli/termly
      {
        apps.cli.termly.enable = true;
      }
    ];
  };

  termlyIsInstalled =
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
        lib.hasPrefix "termly" name)
      eval.config.environment.systemPackages;
in
lib.runTests {
  termlyAddsPackage = {
    expr = termlyIsInstalled;
    expected = true;
  };
}

