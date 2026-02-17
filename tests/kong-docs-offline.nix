{ inputs, system }:
let
  lib = inputs.nixpkgs.lib;
  pkgs = import inputs.nixpkgs { inherit system; };
  eval = lib.nixosSystem {
    inherit system;
    modules = [
      {
        system.stateVersion = "24.11";
      }
      ../modules/apps/cli/kong-docs-offline
      {
        apps.cli.kong-docs-offline.enable = true;
      }
    ];
  };
in
lib.runTests {
  kongDocsOfflineAddsGit = {
    expr = lib.elem pkgs.git eval.config.environment.systemPackages;
    expected = true;
  };
  kongDocsOfflineAddsMake = {
    expr = lib.elem pkgs.gnumake eval.config.environment.systemPackages;
    expected = true;
  };
  kongDocsOfflineAddsGo = {
    expr = lib.elem pkgs.go eval.config.environment.systemPackages;
    expected = true;
  };
  kongDocsOfflineAddsNode = {
    expr = lib.elem pkgs.nodejs_22 eval.config.environment.systemPackages;
    expected = true;
  };
}

