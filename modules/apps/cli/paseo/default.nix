{
  inputs,
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.cli.paseo;
  paseo-pkg = inputs.paseo.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  options.apps.cli.paseo = {
    enable = lib.mkEnableOption "Paseo self-hosted AI coding agent orchestrator";

    service.enable = lib.mkEnableOption "Paseo daemon as a systemd service";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        environment.systemPackages = [ paseo-pkg ];
      }

      (lib.mkIf cfg.service.enable {
        systemd.services.paseo = {
          description = "Paseo AI coding agent daemon";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${paseo-pkg}/bin/paseo";
            User = globals.user.name;
            Restart = "on-failure";
            RestartSec = 5;
          };
        };
      })
    ]
  );
}
