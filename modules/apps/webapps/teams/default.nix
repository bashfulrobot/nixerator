{
  lib,
  config,
  globals,
  ...
}:
let
  mkWebApp = import ../../../../lib/mkWebApp.nix { inherit lib; };
in
mkWebApp {
  inherit config globals;
  name = "teams";
  displayName = "Microsoft Teams";
  url = "https://teams.cloud.microsoft/";
  wmClass = "chrome-teams.cloud.microsoft__-Default";
  icon = ./icon.png;
  iconGlyph = "󰊻";
  categories = [
    "Network"
    "VideoConference"
    "InstantMessaging"
  ];
  mimeTypes = [ "x-scheme-handler/msteams" ];
  defaultFor = {
    "x-scheme-handler/msteams" = [ "teams-webapp.desktop" ];
  };
}
