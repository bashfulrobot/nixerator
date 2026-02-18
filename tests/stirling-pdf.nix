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
      versions = {
        services.stirling-pdf = {
          version = "2.5.0";
          sha256 = "sha256-GvhmTSraBF+vADa307AdM8neFplbobhFvFjv7LHqDXc=";
          iconSha256 = "sha256-PGdkTQezkoyqePen+fpHeJNHTycI1iHMgjngSaGwD1k=";
          repo = "https://github.com/Stirling-Tools/Stirling-PDF";
        };
      };
    };
    modules = [
      { system.stateVersion = "24.11"; }
      ../modules/apps/cli/stirling-pdf
      { apps.cli.stirling-pdf.enable = true; }
    ];
  };

  launcherIsInstalled =
    lib.any
      (p:
        let
          name =
            if builtins.isAttrs p && p ? name then p.name
            else if builtins.isString p then p
            else "";
        in
        lib.hasPrefix "stirling-pdf" name)
      eval.config.environment.systemPackages;
in
lib.runTests {
  stirlingAddsLauncher = {
    expr = launcherIsInstalled;
    expected = true;
  };

  stirlingDefaultPort = {
    expr = eval.config.apps.cli.stirling-pdf.port;
    expected = 8080;
  };

  stirlingDefaultDataDir = {
    expr = eval.config.apps.cli.stirling-pdf.dataDir;
    expected = "/home/testuser/.local/share/stirling-pdf";
  };
}
