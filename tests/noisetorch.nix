{ inputs, system }:
let
  lib = inputs.nixpkgs.lib;
  eval = lib.nixosSystem {
    inherit system;
    modules = [
      {
        system.stateVersion = "24.11";
      }
      ../modules/apps/gui/noisetorch
      {
        apps.gui.noisetorch.enable = true;
      }
    ];
  };
in
lib.runTests {
  noisetorchEnablesProgram = {
    expr = eval.config.programs.noisetorch.enable;
    expected = true;
  };
}

