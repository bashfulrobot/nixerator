{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.gui.obsidian;

in
{
  options = {
    apps.gui.obsidian.enable = lib.mkEnableOption "Obsidian Notes";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [

      # keep-sorted start case=no numeric=yes
      obsidian
      obsidian-export
      # keep-sorted end
    ];
  };
}
