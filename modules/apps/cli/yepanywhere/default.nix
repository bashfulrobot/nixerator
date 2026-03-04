{
  globals,
  lib,
  pkgs,
  config,
  versions,
  ...
}:

let
  cfg = config.apps.cli.yepanywhere;
  yepanywhere = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.yepanywhere = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable yepanywhere — mobile supervision for Claude Code agents.";
      };

      port = lib.mkOption {
        type = lib.types.int;
        default = 3400;
        description = "Port for the yepanywhere web server.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to open the firewall for yepanywhere's port.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.apps.cli.claude-code.enable;
        message = "yepanywhere requires claude-code to be enabled (apps.cli.claude-code.enable = true)";
      }
    ];

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    home-manager.users.${globals.user.name} = {
      home.packages = [ yepanywhere ];

      systemd.user.services.yepanywhere = {
        Unit = {
          Description = "Yepanywhere — mobile supervision for Claude Code agents";
          After = [ "network.target" ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${yepanywhere}/bin/yepanywhere --port ${toString cfg.port}";
          Restart = "on-failure";
          RestartSec = 10;
          Environment = [
            "NODE_ENV=production"
            "HOME=${globals.user.homeDirectory}"
          ];
        };

        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    };
  };
}
