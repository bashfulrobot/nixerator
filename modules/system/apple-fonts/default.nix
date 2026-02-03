{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.system.apple-fonts;
  appleFontsPkgs = inputs.apple-fonts.packages.${pkgs.system};
in
{
  options.system.apple-fonts = {
    enable = lib.mkEnableOption "Apple fonts (SF Pro, SF Mono Nerd, New York)";
  };

  config = lib.mkIf cfg.enable {
    fonts.packages = [
      appleFontsPkgs.sf-pro
      appleFontsPkgs.sf-mono-nerd
      appleFontsPkgs.ny
    ];
  };
}
