{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.system.compat;
in
{
  options = {
    system.compat = {
      enable = lib.mkEnableOption "FHS compatibility symlinks for /bin/bash";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "L+ /bin/bash - - - - ${pkgs.bash}/bin/bash"
    ];
  };
}
