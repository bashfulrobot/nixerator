{ lib, pkgs, config, ... }:

let
  cfg = config.apps.cli.kong-docs-offline;
in
{
  options = {
    apps.cli.kong-docs-offline.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable tooling required to run https://github.com/Kong/developer.konghq.com
        locally for offline documentation use.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      git
      gnumake
      go
      nodejs_22
    ];
  };
}

