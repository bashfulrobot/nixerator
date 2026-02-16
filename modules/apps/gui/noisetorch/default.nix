{ lib, config, ... }:

let
  cfg = config.apps.gui.noisetorch;
in
{
  options = {
    apps.gui.noisetorch.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable NoiseTorch for noise suppression.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.noisetorch.enable = true;
  };
}

