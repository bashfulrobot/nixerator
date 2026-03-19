{
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.gui.comics;
  comics-downloader = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.gui.comics.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable comics suite with Komikku manga reader and comics-downloader.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      # keep-sorted start case=no numeric=yes
      comics-downloader # download comics and manga from various sites
      pkgs.komikku # manga reader for GNOME
      # keep-sorted end
    ];
  };
}
