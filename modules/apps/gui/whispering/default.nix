# Whispering Transcription App Module
#
# Uses local package override from ../../packages/whispering
# Release URL: https://github.com/EpicenterHQ/epicenter/releases
# Current local version: 7.11.0 (see ../../packages/whispering/default.nix)

{ lib, pkgs, config, ... }:

let
  cfg = config.apps.gui.whispering;

in
{
  options = {
    apps.gui.whispering.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Whispering transcription app (using local package override).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Using locally overridden package for Whispering
      # See ../../packages/whispering/default.nix for version details
      whispering
    ];
  };
}


