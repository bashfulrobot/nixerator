{
  lib,
  config,
  ...
}:

let
  cfg = config.apps.gui.localsend;
in
{
  options = {
    apps.gui.localsend = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable LocalSend for local file sharing.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.localsend = {
      enable = true;
      openFirewall = true;
    };
  };
}
