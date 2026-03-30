{
  config,
  lib,
  pkgs,
  versions,
  ...
}:

let
  cfg = config.apps.cli.gws;
  gws = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.gws.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable gws - Google Workspace CLI for Drive, Gmail, Calendar, Sheets, Docs, Chat, Admin, and more.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      gws
      (pkgs.google-cloud-sdk.withExtraComponents [
        pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
      ])
    ];
  };
}
