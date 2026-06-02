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
  name = "slack";
  displayName = "Slack";
  url = "https://kongstrong.slack.com/";
  wmClass = "chrome-kongstrong.slack.com__-Default";
  icon = ./icon.png;
  categories = [
    "Network"
    "InstantMessaging"
  ];
  mimeTypes = [ "x-scheme-handler/slack" ];
  defaultFor = {
    "x-scheme-handler/slack" = [ "slack-webapp.desktop" ];
  };
}
