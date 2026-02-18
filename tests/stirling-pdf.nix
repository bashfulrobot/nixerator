{ inputs, system }:
let
  lib = inputs.nixpkgs.lib;
  eval = lib.nixosSystem {
    inherit system;
    specialArgs = {
      globals = {
        user = {
          name = "testuser";
          homeDirectory = "/home/testuser";
        };
      };
    };
    modules = [
      {
        system.stateVersion = "24.11";
      }
      ../modules/apps/cli/stirling-pdf
      {
        apps.cli.stirling-pdf.enable = true;
      }
    ];
  };

  stirlingIsInstalled =
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
        lib.hasPrefix "stirling-pdf" name)
      eval.config.environment.systemPackages;
in
lib.runTests {
  stirlingAddsPackage = {
    expr = stirlingIsInstalled;
    expected = true;
  };
}
